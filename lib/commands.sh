# shiplog command implementations

cmd_init() {
  ensure_in_repo
  ensure_config_value() {
    local key="$1" value="$2"
    if git config --get-all "$key" 2>/dev/null | grep -Fxq "$value"; then
      return 0
    fi
    git config --add "$key" "$value"
  }

  mapfile -t existing_push < <(git config --get-all remote.origin.push 2>/dev/null || true)
  ensure_config_value remote.origin.fetch "+$REF_ROOT/*:$REF_ROOT/*"
  ensure_config_value remote.origin.push  "$REF_ROOT/*:$REF_ROOT/*"
  if [ ${#existing_push[@]} -eq 0 ]; then
    ensure_config_value remote.origin.push HEAD
  fi

  if [ "$(git config --get core.logAllRefUpdates 2>/dev/null)" != "true" ]; then
    git config core.logAllRefUpdates true
  fi
  if is_boring; then
    printf 'Configured refspecs for %s/* and enabled reflogs.\n' "$REF_ROOT"
  else
    "$GUM" style --border normal --padding "1 2" -- "Configured refspecs for $REF_ROOT/* and enabled reflogs."
  fi
}

cmd_write() {
  ensure_in_repo
  local env="${1:-$DEFAULT_ENV}"

  require_allowed_author
  require_allowed_signer

  local journal_ref="$(ref_journal "$env")"
  local notes_ref="$NOTES_REF"
  local remote_url=""
  remote_url=$(git config --get remote.origin.url 2>/dev/null || true)
  local have_origin=0
  [ -n "$remote_url" ] && have_origin=1

  maybe_sync_shiplog_ref() {
    local ref="$1"
    [ "$have_origin" -eq 1 ] || return 0
    if git ls-remote --exit-code origin "$ref" >/dev/null 2>&1; then
      if git fetch origin "$ref:$ref" >/dev/null 2>&1; then
        return 0
      fi
      if [ "${SHIPLOG_AUTO_PUSH:-1}" != "0" ]; then
        if git push origin "$ref" >/dev/null 2>&1; then
          git fetch origin "$ref:$ref" >/dev/null 2>&1 && return 0
        fi
      fi
      die "shiplog: unable to sync $ref with origin; push or resolve divergence before continuing"
    fi
    return 0
  }

  maybe_sync_shiplog_ref "$journal_ref"
  if [ -n "$notes_ref" ] && [ "$have_origin" -eq 1 ]; then
    git fetch origin "$notes_ref" >/dev/null 2>&1 || true
  fi

  local service status reason ticket region cluster ns artifact_tag artifact_image run_url
  service="$(shiplog_prompt_input "service (e.g., web)" "SHIPLOG_SERVICE")"
  status="$(shiplog_prompt_choice "Status" "SHIPLOG_STATUS" success failed in_progress skipped override revert finalize)"
  reason="$(shiplog_prompt_input "reason (e.g., hotfix 503s)" "SHIPLOG_REASON")"
  ticket="$(shiplog_prompt_input "ticket/PR (optional, e.g., OPS-7421)" "SHIPLOG_TICKET")"
  region="$(shiplog_prompt_input "region (e.g., us-west-2)" "SHIPLOG_REGION")"
  cluster="$(shiplog_prompt_input "cluster (e.g., prod-1)" "SHIPLOG_CLUSTER")"
  ns="$(shiplog_prompt_input "namespace (e.g., pf3)" "SHIPLOG_NAMESPACE")"
  artifact_image="$(shiplog_prompt_input "artifact image (e.g., ghcr.io/acme/web)" "SHIPLOG_IMAGE")"
  artifact_tag="$(shiplog_prompt_input "artifact tag (e.g., 2025-09-19.3)" "SHIPLOG_TAG")"
  run_url="$(shiplog_prompt_input "pipeline/run URL (optional)" "SHIPLOG_RUN_URL")"

  if [ -z "$service" ]; then
    if is_boring; then
      die "shiplog: SHIPLOG_SERVICE environment variable is required in non-interactive mode"
    else
      die "shiplog: service name is required but not provided"
    fi
  fi
  local start_ts end_ts dur_s
  start_ts="$(fmt_ts)"
  if is_boring; then
    sleep 0.01
  else
    "$GUM" spin --spinner line --title "Gathering repo state…" -- sleep 0.2
  fi
  local repo_head; repo_head="$(git rev-parse HEAD)"
  end_ts="$(fmt_ts)"
  dur_s=$(( $(date -u -d "$end_ts" +%s 2>/dev/null || gdate -u -d "$end_ts" +%s) - $(date -u -d "$start_ts" +%s 2>/dev/null || gdate -u -d "$start_ts" +%s) ))

  local artifact=""
  if [ -n "$artifact_image" ] || [ -n "$artifact_tag" ]; then
    if [ -n "$artifact_image" ] && [ -n "$artifact_tag" ]; then
      artifact="${artifact_image}:${artifact_tag}"
    elif [ -n "$artifact_image" ]; then
      artifact="$artifact_image"
    else
      artifact="$artifact_tag"
    fi
  fi

  local msg; msg="$(compose_message "$env" "$service" "$status" "$reason" "$ticket" "$region" "$cluster" "$ns" "$start_ts" "$end_ts" "$dur_s" "$repo_head" "$artifact" "$run_url")"

  if is_boring; then
    printf '%s\n' "$msg"
  else
    "$GUM" style --border normal --title "Preview" --padding "1 2" -- "$msg"
    "$GUM" log --structured --time "rfc822" --level info "{\"preview\":\"$env\",\"status\":\"$status\",\"service\":\"$service\"}" >&2
  fi

  shiplog_confirm "Sign & append this entry to $journal_ref?" || die "Aborted."

  local tree; tree="$(empty_tree)"
  local parent; parent="$(current_tip "$journal_ref")"
  local new
  new="$(printf "%s" "$msg" | sign_commit "$tree" ${parent:+-p "$parent"})" || die "Signing commit failed."

  local note_attached=0
  if [ -n "${SHIPLOG_LOG:-}" ]; then
    attach_note_if_present "$new" "$SHIPLOG_LOG"
    note_attached=1
  fi

  ff_update "$journal_ref" "$new" "$parent" "shiplog: append entry"
  if is_boring; then
    printf '✅ Appended %s to %s\n' "$(git rev-parse --short "$new")" "$(ref_journal "$env")"
  else
    "$GUM" style --border rounded -- "✅ Appended $(git rev-parse --short "$new") to $(ref_journal "$env")"
    "$GUM" log --structured --time "rfc822" --level info "{\"env\":\"$env\",\"status\":\"$status\",\"service\":\"$service\",\"artifact\":\"$artifact\",\"region\":\"$region\",\"cluster\":\"$cluster\",\"namespace\":\"$ns\",\"ticket\":\"$ticket\",\"reason\":\"$reason\"}" >&2
  fi

  if [ "$have_origin" -eq 1 ] && [ "${SHIPLOG_AUTO_PUSH:-1}" != "0" ]; then
    local push_output
    if ! push_output=$(git push origin "$journal_ref" 2>&1); then
      die "shiplog: failed to push $journal_ref to origin: $push_output"
    fi
    if [ "$note_attached" -eq 1 ]; then
      if ! push_output=$(git push origin "$notes_ref" 2>&1); then
        die "shiplog: failed to push $notes_ref to origin: $push_output"
      fi
    fi
    if ! is_boring && command -v "$GUM" >/dev/null 2>&1; then
      "$GUM" style --border normal -- "📤 Pushed $journal_ref to origin"
    elif ! is_boring; then
      printf '📤 Pushed %s to origin\n' "$journal_ref"
    fi
  elif [ "$have_origin" -eq 1 ] && [ "${SHIPLOG_AUTO_PUSH:-1}" = "0" ] && ! is_boring; then
    printf 'ℹ️ shiplog: auto-push disabled; remember to push %s manually.\n' "$journal_ref"
  fi
}

cmd_ls() {
  ensure_in_repo
  local env="${1:-$DEFAULT_ENV}"
  local limit="${2:-20}"
  local ref; ref="$(ref_journal "$env")"
  [ -n "$(current_tip "$ref")" ] || die "No entries at $ref"
  pretty_ls "$ref" "$limit"
}

cmd_show() {
  ensure_in_repo
  local target="${1:-}"
  if [ -z "$target" ]; then
    target="$(ref_journal "$DEFAULT_ENV")"
  fi
  show_entry "$target"
}

cmd_verify() {
  ensure_in_repo
  local env="${1:-$DEFAULT_ENV}"
  local ref; ref="$(ref_journal "$env")"
  local ok=0 bad=0 unauth=0
  while IFS= read -r c; do
    if ensure_signed_on_verify "$c"; then
      author="$(git show -s --format='%ae' "$c")"
      if author_allowed "$author"; then
        ok=$((ok+1))
      else
        unauth=$((unauth+1)); echo "❌ unauthorized author <$author> on $c" >&2
      fi
    else
      bad=$((bad+1)); echo "❌ bad or missing signature on $c" >&2
    fi
  done < <(git rev-list "$(ref_journal "$env")")
  if is_boring; then
    printf 'Verified: OK=%s, BadSig=%s, Unauthorized=%s\n' "$ok" "$bad" "$unauth"
  else
    "$GUM" style --border normal --padding "1 2" -- "Verified: OK=$ok, BadSig=$bad, Unauthorized=$unauth"
  fi
  [ $bad -eq 0 ] && [ $unauth -eq 0 ]
}

cmd_export_json() {
  ensure_in_repo
  local env="${1:-$DEFAULT_ENV}"
  command -v jq >/dev/null 2>&1 || die "jq required for --json export"
  local ref; ref="$(ref_journal "$env")"
  git rev-list "$ref" | while read -r c; do
    git show -s --format=%B "$c" | awk '/^---/{flag=1;next}flag' | jq -c --arg sha "$c" '. + {commit:$sha}'
  done
}

cmd_policy() {
  ensure_in_repo
  resolve_policy

  local boring=0
  if is_boring; then
    boring=1
  fi
  local action=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --boring|-b)
        boring=1
        shift
        ;;
      show|validate)
        action="$1"
        shift
        break
        ;;
      *)
        action="$1"
        shift
        break
        ;;
    esac
  done
  action="${action:-show}"

  case "$action" in
    show|"" )
      local signed_status
      if [ "${SHIPLOG_SIGN_EFFECTIVE:-1}" = "0" ]; then
        signed_status="disabled"
      else
        signed_status="enabled"
      fi
      if [ "$boring" -eq 1 ]; then
        printf 'Source: %s\n' "${POLICY_SOURCE:-default}"
        printf 'Require Signed: %s\n' "$signed_status"
        printf 'Allowed Authors: %s\n' "${ALLOWED_AUTHORS_EFFECTIVE:-<none>}"
        printf 'Allowed Signers File: %s\n' "${SIGNERS_FILE_EFFECTIVE:-<none>}"
        printf 'Notes Ref: %s\n' "${NOTES_REF:-refs/_shiplog/notes/logs}"
      else
        local rows=""
        rows+=$'Source\t'"${POLICY_SOURCE:-default}"$'\n'
        rows+=$'Require Signed\t'"$signed_status"$'\n'
        rows+=$'Allowed Authors\t'"${ALLOWED_AUTHORS_EFFECTIVE:-<none>}"$'\n'
        rows+=$'Allowed Signers File\t'"${SIGNERS_FILE_EFFECTIVE:-<none>}"$'\n'
        rows+=$'Notes Ref\t'"${NOTES_REF:-refs/_shiplog/notes/logs}"$'\n'
        "$GUM" table --separator $'\t' --columns Field,Value <<<"$rows"
      fi
      ;;
    validate)
      printf '%s\n' "Policy source: ${POLICY_SOURCE:-default}" >&2
      ;;
    *)
      die "Unknown policy subcommand: $action"
      ;;
  esac
}

usage() {
usage() {
  local cmd="$(basename "$0")"
  if [ "$cmd" = "git-shiplog" ]; then
    cmd="git shiplog"
  fi
  cat <<EOF
SHIPLOG-Lite
A structured deployment logging tool for Git repositories.

Usage:
  $cmd [GLOBAL_OPTIONS] <command> [COMMAND_OPTIONS]

Commands:
  init                 Initialize shiplog configuration in current repo
  write [ENV]          Create a new deployment log entry
  ls [ENV] [LIMIT]     List recent deployment entries (default: last 20)
  show [COMMIT]        Show detailed deployment entry
  verify [ENV]         Verify signatures and authorization of entries
  export-json [ENV]    Export entries as JSON lines
  policy [show]        Show current policy configuration

Global Options:
  --env ENV            Target environment (default: $DEFAULT_ENV)
  --boring             Non-interactive mode (requires SHIPLOG_* env vars)
  --yes                Auto-confirm all prompts
  --no-push            Skip automatic git push of shiplog refs

Environment Variables:
  SHIPLOG_SERVICE      Service name (required in --boring mode)
  SHIPLOG_STATUS       Deployment status (success|failed|in_progress|...)
  SHIPLOG_REASON       Deployment reason/description
  SHIPLOG_TICKET       Associated ticket or PR number
  SHIPLOG_REGION       Target region
  SHIPLOG_CLUSTER      Target cluster
  SHIPLOG_NAMESPACE    Target namespace
  SHIPLOG_IMAGE        Container image name
  SHIPLOG_TAG          Container image tag
  SHIPLOG_RUN_URL      CI/CD pipeline URL
  SHIPLOG_LOG          Path to log file to attach as notes
  SHIPLOG_AUTO_PUSH    Auto-push to origin (default: 1)
  SHIPLOG_ASSUME_YES   Auto-confirm prompts (default: 0)
  SHIPLOG_BORING       Enable non-interactive mode (default: 0)
EOF
}
run_command() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    init)          cmd_init "$@";;
    write)         cmd_write "$@";;
    ls)            cmd_ls "$@";;
    show)          cmd_show "$@";;
    verify)        cmd_verify "$@";;
    export-json)   cmd_export_json "$@";;
    policy)        cmd_policy "$@";;
    *)             usage; exit 1;;
  esac
}
