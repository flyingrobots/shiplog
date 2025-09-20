# shiplog command implementations

cmd_init() {
  ensure_in_repo
  git config --add remote.origin.fetch "+$REF_ROOT/*:$REF_ROOT/*" || true
  git config --add remote.origin.push  "$REF_ROOT/*:$REF_ROOT/*"  || true
  git config core.logAllRefUpdates true
  $GUM style --border normal --padding "1 2" -- "Configured refspecs for $REF_ROOT/* and enabled reflogs."
}

cmd_write() {
  ensure_in_repo
  local env="${1:-$DEFAULT_ENV}"

  require_allowed_author
  require_allowed_signer

  local service status reason ticket region cluster ns artifact_tag artifact_image run_url
  service=$($GUM input --placeholder "service (e.g., web)" --value "${SHIPLOG_SERVICE:-}")
  status=$($GUM choose success failed in_progress skipped override revert finalize --header "Status")
  reason=$($GUM input --placeholder "reason (e.g., hotfix 503s)" --value "${SHIPLOG_REASON:-}")
  ticket=$($GUM input --placeholder "ticket/PR (optional, e.g., OPS-7421)" --value "${SHIPLOG_TICKET:-}")
  region=$($GUM input --placeholder "region (e.g., us-west-2)" --value "${SHIPLOG_REGION:-}")
  cluster=$($GUM input --placeholder "cluster (e.g., prod-1)" --value "${SHIPLOG_CLUSTER:-}")
  ns=$($GUM input --placeholder "namespace (e.g., pf3)" --value "${SHIPLOG_NAMESPACE:-}")
  artifact_image=$($GUM input --placeholder "artifact image (e.g., ghcr.io/acme/web)" --value "${SHIPLOG_IMAGE:-}")
  artifact_tag=$($GUM input --placeholder "artifact tag (e.g., 2025-09-19.3)" --value "${SHIPLOG_TAG:-}")
  run_url=$($GUM input --placeholder "pipeline/run URL (optional)" --value "${SHIPLOG_RUN_URL:-}")

  local start_ts end_ts dur_s
  start_ts="$(fmt_ts)"
  $GUM spin --spinner line --title "Gathering repo state…" -- sleep 0.2
  local repo_head; repo_head="$(git rev-parse HEAD)"
  end_ts="$(fmt_ts)"
  dur_s=$(( $(date -u -d "$end_ts" +%s 2>/dev/null || gdate -u -d "$end_ts" +%s) - $(date -u -d "$start_ts" +%s 2>/dev/null || gdate -u -d "$start_ts" +%s) ))

  local artifact="${artifact_image}:${artifact_tag}"

  local msg; msg="$(compose_message "$env" "$service" "$status" "$reason" "$ticket" "$region" "$cluster" "$ns" "$start_ts" "$end_ts" "$dur_s" "$repo_head" "$artifact" "$run_url")"

  $GUM style --border normal --title "Preview" --padding "1 2" -- "$msg"
  $GUM confirm "Sign & append this entry to $REF_ROOT/journal/$env?" || die "Aborted."

  local tree; tree="$(empty_tree)"
  local parent; parent="$(current_tip "$(ref_journal "$env")")"
  local new
  new="$(printf "%s" "$msg" | sign_commit "$tree" ${parent:+-p "$parent"})" || die "Signing commit failed."

  if [ -n "${SHIPLOG_LOG:-}" ]; then
    attach_note_if_present "$new" "$SHIPLOG_LOG"
  fi

  ff_update "$(ref_journal "$env")" "$new" "$parent" "shiplog: append entry"
  $GUM style --border rounded -- "✅ Appended $(git rev-parse --short "$new") to $(ref_journal "$env")"
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
  $GUM style --border normal --padding "1 2" -- "Verified: OK=$ok, BadSig=$bad, Unauthorized=$unauth"
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
        $GUM table --separator $'\t' --columns Field,Value <<<"$rows"
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
  cat <<EOF
SHIPLOG-Lite
Usage:
  $(basename "$0") init
  $(basename "$0") write [ENV]
  $(basename "$0") ls   [ENV] [LIMIT]
  $(basename "$0") show [COMMIT|default: $REF_ROOT/journal/$DEFAULT_ENV]
  $(basename "$0") verify [ENV]
  $(basename "$0") export-json [ENV]
  $(basename "$0") policy [show]

Env via $SHIPLOG_ENV (default: $DEFAULT_ENV). Optional vars: SHIPLOG_* (author, image, tag, run url, log).
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
