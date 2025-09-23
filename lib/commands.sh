# shellcheck shell=bash
# shiplog command implementations

has_remote_origin() {
  git config --get remote.origin.url >/dev/null 2>&1
}

get_remote_oid() {
  local ref="$1" output
  if ! output=$(git ls-remote origin "$ref" 2>&1); then
    printf '⚠️ shiplog: unable to query origin for %s (%s)\n' "$ref" "$output" >&2
    return 1
  fi
  printf '%s' "$(printf '%s\n' "$output" | awk 'NF{print $1; exit}')"
}

fast_forward_ref() {
  local ref="$1" context="${2:-fast-forward}"
  local fetch_output
  if ! fetch_output=$(git fetch origin "$ref:$ref" 2>&1); then
    die "shiplog: failed to ${context} $ref from origin: $fetch_output"
  fi
}

check_divergence() {
  local local_oid="$1" remote_oid="$2"
  if [ -z "$remote_oid" ]; then
    printf 'remote-missing'
    return 0
  fi
  if [ "$local_oid" = "$remote_oid" ]; then
    printf 'in-sync'
    return 0
  fi
  if git merge-base --is-ancestor "$local_oid" "$remote_oid" >/dev/null 2>&1; then
    printf 'remote-ahead'
    return 0
  fi
  if git merge-base --is-ancestor "$remote_oid" "$local_oid" >/dev/null 2>&1; then
    printf 'local-ahead'
    return 0
  fi
  printf 'diverged'
}

maybe_sync_shiplog_ref() {
  local ref="$1"
  has_remote_origin || return 0

  local remote_oid
  if ! remote_oid=$(get_remote_oid "$ref"); then
    return 0
  fi
  [ -n "$remote_oid" ] || return 0

  local local_oid
  local_oid=$(git rev-parse "$ref" 2>/dev/null || true)
  if [ -z "$local_oid" ]; then
    fast_forward_ref "$ref" "fetch"
    return 0
  fi

  local state
  state=$(check_divergence "$local_oid" "$remote_oid")
  case "$state" in
    in-sync|local-ahead|remote-missing)
      return 0
      ;;
    remote-ahead)
      fast_forward_ref "$ref"
      ;;
    diverged)
      die "shiplog: $ref has diverged between local and origin; reconcile before writing"
      ;;
  esac
}

cmd_version() {
  printf 'shiplog %s\n' "$(shiplog_version)"
}

cmd_init() {
  ensure_in_repo
  local fetch_value="+$REF_ROOT/*:$REF_ROOT/*"
  if ! git config --get-all remote.origin.fetch 2>/dev/null | grep -Fxq "$fetch_value"; then
    git config --add remote.origin.fetch "$fetch_value"
  fi

  local existing_push
  existing_push=$(git config --get-all remote.origin.push 2>/dev/null || true)
  if ! printf '%s\n' "$existing_push" | grep -Fxq "$REF_ROOT/*:$REF_ROOT/*"; then
    git config --add remote.origin.push "$REF_ROOT/*:$REF_ROOT/*"
  fi
  if [ -z "$existing_push" ] && ! git config --get-all remote.origin.push 2>/dev/null | grep -Fxq "HEAD"; then
    git config --add remote.origin.push HEAD
  fi

  if [ "$(git config --get core.logAllRefUpdates 2>/dev/null)" != "true" ]; then
    git config core.logAllRefUpdates true
  fi
  if shiplog_can_use_bosun; then
    local bosun
    bosun=$(shiplog_bosun_bin)
    "$bosun" style --title "Init" -- "Configured refspecs for $REF_ROOT/* and enabled reflogs."
  else
    printf 'Configured refspecs for %s/* and enabled reflogs.\n' "$REF_ROOT"
  fi
}

cmd_write() {
  ensure_in_repo
  local env="${1:-$DEFAULT_ENV}"

  require_allowed_author
  require_allowed_signer

  local journal_ref="$(ref_journal "$env")"
  local notes_ref="$NOTES_REF"
  local trust_ref="${TRUST_REF:-$TRUST_REF_DEFAULT}"
  local origin_available=0
  if has_remote_origin; then
    origin_available=1
    maybe_sync_shiplog_ref "$trust_ref"
    maybe_sync_shiplog_ref "$journal_ref"
    if [ -n "$notes_ref" ]; then
      git fetch origin "$notes_ref" >/dev/null 2>&1 || true
    fi
  fi

  local trust_oid
  trust_oid=$(git rev-parse -q --verify "$trust_ref" 2>/dev/null || true)
  if [ -z "$trust_oid" ]; then
    die "shiplog: trust ref $trust_ref not found. Fetch it (git fetch origin '+refs/_shiplog/trust/*:refs/_shiplog/trust/*') and run ./scripts/shiplog-trust-sync.sh"
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

  if [ -z "$service" ] && [ "${SHIPLOG_ASSUME_YES:-0}" = "1" ]; then
    service="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo default)")"
  fi
  if [ -z "$service" ]; then
    if is_boring || [ "${SHIPLOG_ASSUME_YES:-0}" = "1" ]; then
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
    if shiplog_can_use_bosun; then
      local bosun
      bosun=$(shiplog_bosun_bin)
      "$bosun" spin --title "Gathering repo state…" -- sleep 0.2
    else
      sleep 0.2
    fi
  fi
  local repo_head; repo_head="$(git rev-parse HEAD)"
  end_ts="$(fmt_ts)"
  dur_s=$(( $(date -u -d "$end_ts" +%s 2>/dev/null || gdate -u -d "$end_ts" +%s) - $(date -u -d "$start_ts" +%s 2>/dev/null || gdate -u -d "$start_ts" +%s) ))

  local artifact=""
  if [ -n "$artifact_image" ]; then
    artifact="${artifact_image}${artifact_tag:+:$artifact_tag}"
  else
    artifact="$artifact_tag"
  fi

  local parent seq=0
  parent="$(current_tip "$journal_ref")"
  if [ -n "$parent" ]; then
    local prev_seq
    prev_seq=$(trailer_value "$parent" '.seq') || die "shiplog: unable to read seq from previous journal entry $parent"
    if [ "$prev_seq" = "null" ] || ! printf '%s' "$prev_seq" | grep -Eq '^[0-9]+$'; then
      die "shiplog: previous journal entry $parent missing numeric seq"
    fi
    seq=$((prev_seq + 1))
  fi

  local anchor_ref="$(ref_anchor "$env")"
  local previous_anchor
  previous_anchor="$(current_tip "$anchor_ref")"

  local author_name author_email
  author_name="${GIT_AUTHOR_NAME:-${SHIPLOG_AUTHOR_NAME:-$(git config user.name || echo '')}}"
  author_email="${GIT_AUTHOR_EMAIL:-${SHIPLOG_AUTHOR_EMAIL:-$(git config user.email || echo '')}}"
  [ -n "$author_email" ] || die "shiplog: unable to determine author email"

  local write_ts
  write_ts="$(fmt_ts)"

  local msg; msg="$(compose_message "$env" "$service" "$status" "$reason" "$ticket" "$region" "$cluster" "$ns" "$start_ts" "$end_ts" "$dur_s" "$repo_head" "$artifact" "$run_url" "$seq" "$parent" "$trust_oid" "$previous_anchor" "$write_ts" "$author_name" "$author_email")"
  # Apply plugin filter if available, fallback gracefully if not
  if command -v shiplog_plugins_filter >/dev/null 2>&1; then
    msg=$(shiplog_plugins_filter "pre-commit-message" "$msg")
  fi

  if shiplog_can_use_bosun; then
    local bosun
    bosun=$(shiplog_bosun_bin)
    "$bosun" style --title "Preview" -- "$msg"
    shiplog_log_structured "{\"preview\":\"$env\",\"status\":\"$status\",\"service\":\"$service\"}"
  else
    printf '%s\n' "$msg"
    if ! is_boring; then
      shiplog_log_structured "{\"preview\":\"$env\",\"status\":\"$status\",\"service\":\"$service\"}"
    fi
  fi

  shiplog_confirm "Sign & append this entry to $journal_ref?" || die "Aborted."

  local tree; tree="$(empty_tree)"
  local new
  new="$(printf "%s" "$msg" | sign_commit "$tree" ${parent:+-p "$parent"})" || die "Signing commit failed."

  local note_attached=0
  if [ -n "${SHIPLOG_LOG:-}" ]; then
    attach_note_if_present "$new" "$SHIPLOG_LOG"
    note_attached=1
  fi

  ff_update "$journal_ref" "$new" "$parent" "shiplog: append entry"
  local append_message="✅ Appended $(git rev-parse --short "$new") to $(ref_journal "$env")"
  if shiplog_can_use_bosun; then
    local bosun
    bosun=$(shiplog_bosun_bin)
    "$bosun" style --title "Write" -- "$append_message"
    shiplog_log_structured "{\"env\":\"$env\",\"status\":\"$status\",\"service\":\"$service\",\"artifact\":\"$artifact\",\"region\":\"$region\",\"cluster\":\"$cluster\",\"namespace\":\"$ns\",\"ticket\":\"$ticket\",\"reason\":\"$reason\"}"
  else
    printf '%s\n' "$append_message"
    if ! is_boring; then
      shiplog_log_structured "{\"env\":\"$env\",\"status\":\"$status\",\"service\":\"$service\",\"artifact\":\"$artifact\",\"region\":\"$region\",\"cluster\":\"$cluster\",\"namespace\":\"$ns\",\"ticket\":\"$ticket\",\"reason\":\"$reason\"}"
    fi
  fi

  if [ "$origin_available" -eq 1 ] && [ "${SHIPLOG_AUTO_PUSH:-1}" != "0" ]; then
    local push_output
    if ! push_output=$(git push origin "$journal_ref" 2>&1); then
      die "shiplog: failed to push $journal_ref to origin: $push_output"
    fi
    if [ "$note_attached" -eq 1 ]; then
      if ! push_output=$(git push origin "$notes_ref" 2>&1); then
        die "shiplog: failed to push $notes_ref to origin: $push_output"
      fi
    fi
    if shiplog_can_use_bosun; then
      local bosun
      bosun=$(shiplog_bosun_bin)
      "$bosun" style --title "Push" -- "📤 Pushed $journal_ref to origin"
    elif ! is_boring; then
      printf '📤 Pushed %s to origin\n' "$journal_ref"
    fi
  elif [ "$origin_available" -eq 1 ] && [ "${SHIPLOG_AUTO_PUSH:-1}" = "0" ] && ! is_boring; then
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
  local verify_summary="Verified: OK=$ok, BadSig=$bad, Unauthorized=$unauth"
  if shiplog_can_use_bosun; then
    local bosun
    bosun=$(shiplog_bosun_bin)
    "$bosun" style --title "Verify" -- "$verify_summary"
  else
    printf '%s\n' "$verify_summary"
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
      if [ "$boring" -eq 1 ] || ! shiplog_can_use_bosun; then
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
        local bosun
        bosun=$(shiplog_bosun_bin)
        printf '%s' "$rows" | "$bosun" table --columns "Field,Value"
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

cmd_trust() {
  ensure_in_repo
  local action="${1:-sync}"
  shift || true
  case "$action" in
    sync)
      local ref="${1:-${TRUST_REF:-$TRUST_REF_DEFAULT}}"
      local dest="${2:-.shiplog/allowed_signers}"
      [ -x "$SHIPLOG_HOME/scripts/shiplog-trust-sync.sh" ] || die "shiplog: trust sync helper missing at $SHIPLOG_HOME/scripts/shiplog-trust-sync.sh"
      "$SHIPLOG_HOME"/scripts/shiplog-trust-sync.sh "$ref" "$dest"
      ;;
    *)
      die "Unknown trust subcommand: $action"
      ;;
  esac
}

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
  version             Print Shiplog version
  init                 Initialize shiplog configuration in current repo
  write [ENV]          Create a new deployment log entry
  ls [ENV] [LIMIT]     List recent deployment entries (default: last 20)
  show [COMMIT]        Show detailed deployment entry
  verify [ENV]         Verify signatures and authorization of entries
  export-json [ENV]    Export entries as JSON lines
  trust sync [REF]     Refresh signer roster from the trust ref (default: refs/_shiplog/trust/root)
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
    version)       cmd_version "$@";;
    init)          cmd_init "$@";;
    write)         cmd_write "$@";;
    ls)            cmd_ls "$@";;
    show)          cmd_show "$@";;
    verify)        cmd_verify "$@";;
    export-json)   cmd_export_json "$@";;
    trust)         cmd_trust "$@";;
    policy)        cmd_policy "$@";;
    *)             usage; exit 1;;
  esac
}
