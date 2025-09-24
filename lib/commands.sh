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

policy_install_file() {
  local new_file="$1" dest_file="$2"
  normalize_json_file() {
    local f="$1"
    if command -v jq >/dev/null 2>&1; then
      local tmpn; tmpn=$(mktemp)
      if jq -S . "$f" >"$tmpn" 2>/dev/null; then
        mv "$tmpn" "$f"
      else
        rm -f "$tmpn" 2>/dev/null || true
      fi
    fi
  }
  if [ ! -f "$dest_file" ]; then
    mv "$new_file" "$dest_file"
    normalize_json_file "$dest_file"
    return 0
  fi
  if cmp -s "$new_file" "$dest_file" 2>/dev/null; then
    rm -f "$new_file"
    if shiplog_can_use_bosun; then
      local bosun; bosun=$(shiplog_bosun_bin)
      "$bosun" style --title "Policy" -- "No changes to $dest_file"
    else
      printf 'No changes to %s\n' "$dest_file"
    fi
    return 0
  fi
  # If contents differ but JSON bodies are identical, treat as no-op (avoid backup churn across distros)
  if command -v jq >/dev/null 2>&1; then
    local old_norm new_norm
    old_norm=$(jq -cS . "$dest_file" 2>/dev/null || true)
    new_norm=$(jq -cS . "$new_file" 2>/dev/null || true)
    if [ -n "$old_norm" ] && [ -n "$new_norm" ] && [ "$old_norm" = "$new_norm" ]; then
      rm -f "$new_file"
      if shiplog_can_use_bosun; then
        local bosun; bosun=$(shiplog_bosun_bin)
        "$bosun" style --title "Policy" -- "No semantic changes to $dest_file"
      else
        printf 'No semantic changes to %s\n' "$dest_file"
      fi
      return 0
    fi
  fi
  local ts backup diffout
  ts="$(date +%Y%m%d%H%M%S)"
  backup="${dest_file}.bak.${ts}"
  cp "$dest_file" "$backup"
  if command -v git >/dev/null 2>&1; then
    diffout="$(git --no-pager diff --no-index --color=never -- "$dest_file" "$new_file" 2>/dev/null || true)"
  else
    diffout="$(diff -u "$dest_file" "$new_file" 2>/dev/null || true)"
  fi
  mv "$new_file" "$dest_file"
  normalize_json_file "$dest_file"
  if shiplog_can_use_bosun; then
    local bosun; bosun=$(shiplog_bosun_bin)
    "$bosun" style --title "Policy Backup" -- "Saved previous policy to $backup"
    if [ -n "$diffout" ]; then
      "$bosun" style --title "Policy Diff" -- "$diffout"
    fi
  else
    printf 'Backed up previous policy to %s\n' "$backup"
    [ -n "$diffout" ] && printf '%s\n' "$diffout"
  fi
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
  local json_only=0 boring_local=0 compact=0
  local args=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json_only=1; shift; continue ;;
      --json-compact|--jsonl) json_only=1; compact=1; shift; continue ;;
      --boring|-b) boring_local=1; shift; continue ;;
      --) shift; break ;;
      -*) args+=("$1"); shift; continue ;;
      *) break ;;
    esac
  done
  # If --boring passed after subcommand, honor it
  if [ "$boring_local" -eq 1 ]; then
    SHIPLOG_BORING=1; export SHIPLOG_BORING
  fi

  local target="${1:-}"
  if [ -z "$target" ]; then
    target="$(ref_journal "$DEFAULT_ENV")"
  fi

  if [ "$json_only" -eq 1 ]; then
    local body json
    body="$(git show -s --format=%B "$target")"
    json="$(awk '/^---/{flag=1;next}flag' <<< "$body")"
    if [ -z "$json" ]; then
      die "No JSON payload found in entry $target"
    fi
    if [ "$compact" -eq 1 ]; then
      if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$json" | jq -c .
      else
        # Best-effort: collapse whitespace
        printf '%s\n' "$json" | tr -d '\n' | tr -s ' '
      fi
    else
      if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$json" | jq .
      else
        printf '%s\n' "$json"
      fi
    fi
    return 0
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

  local boring=0 as_json=0 action=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --boring|-b) boring=1; shift ;;
      --json) as_json=1; shift ;;
      show|validate|require-signed|toggle) action="$1"; shift; break ;;
      *) action="$1"; shift; break ;;
    esac
  done
  action="${action:-show}"

  # Parse any trailing flags after the action (e.g., `policy show --json`)
  while [ $# -gt 0 ]; do
    case "$1" in
      --boring|-b) boring=1; shift ;;
      --json) as_json=1; shift ;;
      --) shift; break ;;
      *) break ;;
    esac
  done

  if [ "$as_json" -eq 1 ]; then
    command -v jq >/dev/null 2>&1 || die "jq required for --json output"
  fi

  load_raw_policy() {
    local raw=""
    if git rev-parse --verify "$POLICY_REF" >/dev/null 2>&1; then
      raw=$(git show "$POLICY_REF:.shiplog/policy.json" 2>/dev/null || true)
    fi
    if [ -z "$raw" ] && [ -f ".shiplog/policy.json" ]; then
      raw=$(cat .shiplog/policy.json 2>/dev/null || true)
    fi
    printf '%s' "$raw"
  }

  case "$action" in
    show|"")
      local require_signed_bool="false"
      [ "${SHIPLOG_SIGN_EFFECTIVE:-0}" != "0" ] && require_signed_bool="true"
      if [ "$as_json" -eq 1 ]; then
        local raw_policy env_map
        raw_policy=$(load_raw_policy); [ -n "$raw_policy" ] || raw_policy='{}'
        # Derive env_require_signed map safely even if policy is minimal
        env_map=$(printf '%s\n' "$raw_policy" | jq -c '(.deployment_requirements // {}) | with_entries(.value = (.value.require_signed // null))' 2>/dev/null || printf '{}')
        jq -n \
          --arg source "${POLICY_SOURCE:-default}" \
          --arg authors "${ALLOWED_AUTHORS_EFFECTIVE:-}" \
          --arg signers "${SIGNERS_FILE_EFFECTIVE:-}" \
          --arg notes "${NOTES_REF:-refs/_shiplog/notes/logs}" \
          --argjson req "$require_signed_bool" \
          --argjson env "$env_map" \
          '{source:$source, require_signed:$req, allowed_authors:$authors, allowed_signers_file:$signers, notes_ref:$notes, env_require_signed:$env}' \
          || printf '{"source":"%s","require_signed":%s,"allowed_authors":"%s","allowed_signers_file":"%s","notes_ref":"%s","env_require_signed":{}}\n' \
               "${POLICY_SOURCE:-default}" "$require_signed_bool" "${ALLOWED_AUTHORS_EFFECTIVE:-}" "${SIGNERS_FILE_EFFECTIVE:-}" "${NOTES_REF:-refs/_shiplog/notes/logs}"
      else
        local signed_status; if [ "$require_signed_bool" = "true" ]; then signed_status="enabled"; else signed_status="disabled"; fi
        if [ "$boring" -eq 1 ] || ! shiplog_can_use_bosun; then
          printf 'Source: %s
' "${POLICY_SOURCE:-default}"
          printf 'Require Signed: %s
' "$signed_status"
          printf 'Allowed Authors: %s
' "${ALLOWED_AUTHORS_EFFECTIVE:-<none>}"
          printf 'Allowed Signers File: %s
' "${SIGNERS_FILE_EFFECTIVE:-<none>}"
          printf 'Notes Ref: %s
' "${NOTES_REF:-refs/_shiplog/notes/logs}"
          local raw_policy; raw_policy=$(load_raw_policy)
          if [ -n "$raw_policy" ]; then
            printf '%s
' "$raw_policy" | jq -r '(.deployment_requirements // {}) | to_entries | map(select(.value.require_signed != null)) | .[] | "Require Signed (\(.key)): \(.value.require_signed)"' 2>/dev/null || true
          fi
        else
          local rows="" raw_policy
          rows+=$'Source	'"${POLICY_SOURCE:-default}"$'
'
          rows+=$'Require Signed	'"$signed_status"$'
'
          rows+=$'Allowed Authors	'"${ALLOWED_AUTHORS_EFFECTIVE:-<none>}"$'
'
          rows+=$'Allowed Signers File	'"${SIGNERS_FILE_EFFECTIVE:-<none>}"$'
'
          rows+=$'Notes Ref	'"${NOTES_REF:-refs/_shiplog/notes/logs}"$'
'
          raw_policy=$(load_raw_policy)
          if [ -n "$raw_policy" ]; then
            printf '%s
' "$raw_policy" | jq -r '(.deployment_requirements // {}) | to_entries | map(select(.value.require_signed != null)) | .[] | "\(.key)	\(.value.require_signed)"' 2>/dev/null | while IFS=$'	' read -r env_name env_req; do
              [ -z "$env_name" ] && continue
              rows+=$'Require Signed ('"$env_name"$')	'"$env_req"$'
'
            done
          fi
          local bosun; bosun=$(shiplog_bosun_bin)
          printf '%s' "$rows" | "$bosun" table --columns "Field,Value"
        fi
      fi
      ;;
    validate)
      printf '%s
' "Policy source: ${POLICY_SOURCE:-default}" >&2 ;;
    require-signed)
      local val="${1:-}"; case "$(printf '%s' "$val" | tr '[:upper:]' '[:lower:]')" in 1|true|yes|on) val=true ;; 0|false|no|off) val=false ;; *) die "Usage: git shiplog policy require-signed <true|false>" ;; esac
      mkdir -p .shiplog; local policy_file=".shiplog/policy.json" tmp; tmp=$(mktemp)
      if [ -f "$policy_file" ]; then jq --argjson rs "$val" '(.version // 1) as $v | .version=$v | .require_signed=$rs' "$policy_file" >"$tmp" 2>/dev/null || { rm -f "$tmp"; die "shiplog: failed to update $policy_file"; }
      else printf '{"version":1,"require_signed":%s}
' "$val" >"$tmp"; fi
      policy_install_file "$tmp" "$policy_file"
      if shiplog_can_use_bosun; then local bosun; bosun=$(shiplog_bosun_bin); "$bosun" style --title "Policy" -- "Set require_signed to $val in $policy_file"; else printf 'Set require_signed to %s in %s
' "$val" "$policy_file"; fi
      if [ -x "$SHIPLOG_HOME/scripts/shiplog-sync-policy.sh" ]; then SHIPLOG_POLICY_SIGN=${SHIPLOG_POLICY_SIGN:-0} "$SHIPLOG_HOME/scripts/shiplog-sync-policy.sh" "$policy_file" >/dev/null; if shiplog_can_use_bosun; then local bosun; bosun=$(shiplog_bosun_bin); "$bosun" style --title "Policy" -- "📤 Updated refs/_shiplog/policy/current (push to publish)"; else printf 'Updated policy ref locally. Run: git push origin refs/_shiplog/policy/current
'; fi; else printf 'Note: sync helper missing; commit and publish policy manually.
'; fi ;;
    toggle)
      local current="${SHIPLOG_SIGN_EFFECTIVE:-0}"; local new="false"; [ "$current" = "0" ] && new=true || new=false; cmd_policy require-signed "$new" ;;
    *) die "Unknown policy subcommand: $action" ;;
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

# Refs management
cmd_refs() {
  ensure_in_repo
  local sub="${1:-}"; shift || true
  case "$sub" in
    root)
      local action="${1:-show}"; shift || true
      case "$action" in
        show)
          # Order of precedence: env, git config, default
          local current_root
          current_root="${SHIPLOG_REF_ROOT:-}"
          if [ -z "$current_root" ]; then
            current_root=$(git config --get shiplog.refRoot 2>/dev/null || true)
          fi
          current_root="${current_root:-$REF_ROOT}"
          printf '%s\n' "$current_root"
          ;;
        set)
          local new_root="${1:-}"
          if [ -z "$new_root" ]; then
            die "Usage: git shiplog refs root set <refs/...>"
          fi
          case "$new_root" in refs/*) : ;; *) die "Ref root must start with 'refs/'" ;; esac
          git config shiplog.refRoot "$new_root"
          if shiplog_can_use_bosun; then
            local bosun; bosun=$(shiplog_bosun_bin)
            "$bosun" style --title "Ref Root" -- "Set shiplog.refRoot to $new_root"
          else
            printf 'Set shiplog.refRoot to %s\n' "$new_root"
          fi
          ;;
        *) die "Unknown refs root action: $action" ;;
      esac
      ;;
    migrate)
      if [ ! -x "$SHIPLOG_HOME/scripts/shiplog-migrate-ref-root.sh" ]; then
        die "migration helper missing: $SHIPLOG_HOME/scripts/shiplog-migrate-ref-root.sh"
      fi
      "$SHIPLOG_HOME/scripts/shiplog-migrate-ref-root.sh" "$@"
      ;;
    *) die "Unknown refs subcommand: ${sub:-<none>}" ;;
  esac
}

# Setup wizard (non-interactive wrapper)
cmd_setup() {
  ensure_in_repo

  # Defaults
  local strictness="${SHIPLOG_SETUP_STRICTNESS:-open}"
  local authors_in="${SHIPLOG_SETUP_AUTHORS:-}" # space-separated emails
  local strict_envs_in="${SHIPLOG_SETUP_STRICT_ENVS:-}" # space-separated env names
  local do_auto_push=0
  local dry_run=0
  # Trust passthrough args
  local -a trust_args; trust_args=()
  local dry_run=0

  # Parse options (no prompts)
  while [ $# -gt 0 ]; do
    case "$1" in
      --strictness)
        shift; strictness="${1:-}"; [ -n "$strictness" ] || die "shiplog: --strictness requires a value"; shift ;;
      --strictness=*)
        strictness="${1#*=}"; shift ;;
      --authors)
        shift; authors_in="${1:-}"; [ -n "$authors_in" ] || die "shiplog: --authors requires a value"; shift ;;
      --authors=*)
        authors_in="${1#*=}"; shift ;;
      --strict-envs)
        shift; strict_envs_in="${1:-}"; [ -n "$strict_envs_in" ] || die "shiplog: --strict-envs requires a value"; shift ;;
      --strict-envs=*)
        strict_envs_in="${1#*=}"; shift ;;
      --auto-push)
        do_auto_push=1; shift ;;
      --no-auto-push)
        do_auto_push=0; shift ;;
      --dry-run)
        dry_run=1; export SHIPLOG_SETUP_DRY_RUN=1; shift ;;
      # Trust bootstrap pass-through options (non-interactive)
      --trust-id)
        shift; [ -n "${1:-}" ] || die "shiplog: --trust-id requires a value"; trust_args+=("--trust-id" "$1"); shift ;;
      --trust-id=*)
        trust_args+=("--trust-id=${1#*=}"); shift ;;
      --trust-threshold)
        shift; [ -n "${1:-}" ] || die "shiplog: --trust-threshold requires a value"; trust_args+=("--trust-threshold" "$1"); shift ;;
      --trust-threshold=*)
        trust_args+=("--trust-threshold=${1#*=}"); shift ;;
      --trust-maintainer)
        shift; [ -n "${1:-}" ] || die "shiplog: --trust-maintainer requires a value"; trust_args+=("--trust-maintainer" "$1"); shift ;;
      --trust-maintainer=*)
        trust_args+=("--trust-maintainer=${1#*=}"); shift ;;
      --trust-message)
        shift; [ -n "${1:-}" ] || die "shiplog: --trust-message requires a value"; trust_args+=("--trust-message" "$1"); shift ;;
      --trust-message=*)
        trust_args+=("--trust-message=${1#*=}"); shift ;;
      --help|-h)
        printf 'Usage: git shiplog setup [--strictness open|balanced|strict] [--authors "a@b c@d"] [--strict-envs "prod staging"] [--auto-push]\n' ; return 0 ;;
      --)
        shift; break ;;
      *)
        # Unknown option; show usage and fail
        die "shiplog: unknown setup option: $1" ;;
    esac
  done

  # Env override for auto-push
  case "${SHIPLOG_SETUP_AUTO_PUSH:-}" in
    1|true|yes|on) do_auto_push=1 ;;
    0|false|no|off|'') : ;;
  esac

  # Env override for dry-run
  case "${SHIPLOG_SETUP_DRY_RUN:-}" in
    1|true|yes|on) dry_run=1 ;;
  esac

  # Normalize strictness
  case "$(printf '%s' "$strictness" | tr '[:upper:]' '[:lower:]')" in
    open|balanced|strict) strictness="$(printf '%s' "$strictness" | tr '[:upper:]' '[:lower:]')" ;;
    *) die "shiplog: --strictness must be one of: open|balanced|strict" ;;
  esac

  # Build policy JSON
  mkdir -p .shiplog
  local tmp; tmp=$(mktemp)
  local require_signed_global="false"
  local authors_json='[]'
  local strict_envs_json='[]'

  # Convert space-separated lists to JSON arrays
  if [ -n "$authors_in" ]; then
    # squeeze spaces and split
    authors_json=$(printf '%s\n' "$authors_in" | tr ',;' '  ' | tr -s ' ' | awk '{for(i=1;i<=NF;i++) print $i}' | jq -R . | jq -s .)
  fi
  if [ -n "$strict_envs_in" ]; then
    strict_envs_json=$(printf '%s\n' "$strict_envs_in" | tr ',;' '  ' | tr -s ' ' | awk '{for(i=1;i<=NF;i++) print $i}' | jq -R . | jq -s .)
  fi

  # Determine policy shape
  case "$strictness" in
    open)
      require_signed_global="false"
      ;;
    balanced)
      require_signed_global="false"
      ;;
    strict)
      if [ -n "$strict_envs_in" ]; then
        require_signed_global="false"
      else
        require_signed_global="true"
      fi
      ;;
  esac

  # Start base policy
  printf '{"version":1,"require_signed":%s}\n' "$require_signed_global" >"$tmp"

  # Add authors for balanced
  if [ "$strictness" = "balanced" ] && [ -n "$authors_in" ]; then
    jq --argjson list "$authors_json" '.authors = {default_allowlist: $list, env_overrides: {default: []}}' "$tmp" >"${tmp}.2" && mv "${tmp}.2" "$tmp"
  fi

  # Add per-env deployment requirements for strict with envs
  if [ "$strictness" = "strict" ] && [ -n "$strict_envs_in" ]; then
    jq --argjson envs "$strict_envs_json" '
      .deployment_requirements |= (
        . // {} |
        reduce ($envs[]) as $e (. ; .[$e] = {require_signed:true})
      )
    ' "$tmp" >"${tmp}.2" && mv "${tmp}.2" "$tmp"
  fi

  if [ "$dry_run" -eq 1 ]; then
    # Preview only; do not write or sync
    if shiplog_can_use_bosun; then
      local bosun; bosun=$(shiplog_bosun_bin)
      "$bosun" style --title "Setup (dry-run)" -- "Previewing .shiplog/policy.json (no changes written)"
      "$bosun" style --title "Proposed Policy" -- "$(cat "$tmp")"
    else
      printf 'Setup (dry-run): would write .shiplog/policy.json with contents below:\n'
      cat "$tmp"
      printf '\n'
    fi
    rm -f "$tmp"
  else
    # Install policy file with backup/diff semantics
    policy_install_file "$tmp" ".shiplog/policy.json"

    # Sync policy ref locally (no push here)
    if [ -x "$SHIPLOG_HOME/scripts/shiplog-sync-policy.sh" ]; then
      SHIPLOG_POLICY_SIGN=${SHIPLOG_POLICY_SIGN:-0} "$SHIPLOG_HOME/scripts/shiplog-sync-policy.sh" .shiplog/policy.json >/dev/null
    else
      printf 'Note: sync helper missing; commit and publish policy manually.\n'
    fi

  # Bootstrap trust only when explicitly requested via trust_args OR strict globally with envs provided
  if [ -x "$SHIPLOG_HOME/scripts/shiplog-bootstrap-trust.sh" ]; then
    if [ ${#trust_args[@]} -gt 0 ]; then
      "$SHIPLOG_HOME/scripts/shiplog-bootstrap-trust.sh" --no-push "${trust_args[@]}" >/dev/null || die "shiplog: trust bootstrap failed"
    elif [ "$strictness" = "strict" ] && [ -z "$strict_envs_in" ]; then
      "$SHIPLOG_HOME/scripts/shiplog-bootstrap-trust.sh" --no-push >/dev/null || die "shiplog: trust bootstrap failed (provide SHIPLOG_TRUST_* env for non-interactive)"
    fi
  fi

    # Handle optional auto-push to origin
    if [ "$do_auto_push" -eq 1 ] && has_remote_origin; then
      # Push policy ref if it exists
      if git rev-parse --verify "$POLICY_REF" >/dev/null 2>&1; then
        git push origin "$POLICY_REF" >/dev/null
      fi
      # Push trust ref if it exists
      if git rev-parse --verify "$TRUST_REF" >/dev/null 2>&1; then
        git push origin "$TRUST_REF" >/dev/null
      fi
    fi
  fi

  if shiplog_can_use_bosun; then
    local bosun; bosun=$(shiplog_bosun_bin)
    if [ "$dry_run" -eq 0 ]; then
      "$bosun" style --title "Setup" -- "Wrote .shiplog/policy.json (strictness: $strictness)"
      "$bosun" style --title "Setup" -- "Updated $POLICY_REF locally (run git push origin $POLICY_REF to publish)"
    else
      "$bosun" style --title "Setup" -- "Dry-run: no files or refs changed"
    fi
    if [ "$do_auto_push" -eq 1 ]; then
      "$bosun" style --title "Setup" -- "Auto-pushed configured refs to origin"
    fi
    # Always print next-step commands (advice only)
    "$bosun" style --title "Next Steps" -- $'Configure local signing (optional):\n  git config --local user.name "Your Name"\n  git config --local user.email "you@example.com"\n  git config --local gpg.format ssh\n  git config --local user.signingkey ~/.ssh/your_signing_key.pub\n  git config --local commit.gpgSign true'
    if [ "$do_auto_push" -eq 0 ]; then
      "$bosun" style --title "Next Steps" -- $'Publish refs when ready:\n  git push origin '"$POLICY_REF"$'\n  [if created] git push origin '"$TRUST_REF"''
    fi
    "$bosun" style --title "Next Steps" -- $'Inspect effective policy:\n  git shiplog policy show --json'
  else
    if [ "$dry_run" -eq 0 ]; then
      printf 'Wrote .shiplog/policy.json (strictness: %s)\n' "$strictness"
      printf 'Updated %s locally. Run: git push origin %s\n' "$POLICY_REF" "$POLICY_REF"
      [ "$do_auto_push" -eq 1 ] && printf 'Auto-pushed configured refs to origin.\n'
    else
      printf 'Dry-run: no files or refs changed.\n'
    fi
    printf '%s\n' "Next steps (copy/paste as needed):"
    printf '  %s\n' "git config --local user.name \"Your Name\""
    printf '  %s\n' "git config --local user.email \"you@example.com\""
    printf '  %s\n' "git config --local gpg.format ssh"
    printf '  %s\n' "git config --local user.signingkey ~/.ssh/your_signing_key.pub"
    printf '  %s\n' "git config --local commit.gpgSign true"
    if [ "$do_auto_push" -eq 0 ]; then
      printf '  %s\n' "git push origin $POLICY_REF"
      printf '  %s\n' "[if created] git push origin $TRUST_REF"
    fi
    printf '  %s\n' "git shiplog policy show --json"
  fi
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
  policy require-signed <true|false>
                       Set signing requirement in .shiplog/policy.json and sync policy ref
  policy toggle        Toggle signing requirement (unsigned ↔ signed) and sync policy ref
  refs root show       Show current Shiplog ref root
  refs root set REF    Set Shiplog ref root (e.g., refs/_shiplog or refs/heads/_shiplog)
  refs migrate [OPTS]  Mirror refs between roots (wrapper). Options: --to <refs/...> [--from <refs/...>] [--push] [--remove-old] [--dry-run]
  setup                Non-interactive setup wrapper to write .shiplog/policy.json and sync policy ref
                       Options:
                         --strictness open|balanced|strict
                         --authors "a@b c@d" (balanced)
                         --strict-envs "prod staging" (strict per-env)
                         --auto-push (push policy/trust refs to origin)

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
    refs)          cmd_refs "$@";;
    setup)         cmd_setup "$@";;
    *)             usage; exit 1;;
  esac
}
