#!/usr/bin/env bash
set -euo pipefail

# SHIPLOG-Lite — Bash + gum MVP
# Hidden refs: refs/_shiplog/journal/<env>
# Notes: refs/_shiplog/notes/logs

# -------- Config --------
REF_ROOT="${SHIPLOG_REF_ROOT:-refs/_shiplog}"
NOTES_REF="${SHIPLOG_NOTES_REF:-refs/_shiplog/notes/logs}"
DEFAULT_ENV="${SHIPLOG_ENV:-prod}"
AUTHOR_ALLOWLIST="${SHIPLOG_AUTHORS:-}"        # "a@b c@d"
ALLOWED_SIGNERS_FILE="${SHIPLOG_ALLOWED_SIGNERS:-.git/allowed_signers}"  # for SSH signing verify
GUM=${GUM:-gum}

# -------- Helpers --------
die() { echo "❌ $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

need git
need "$GUM"

export GIT_ALLOW_REFNAME_COMPONENTS_STARTING_WITH_DOT=1

ref_journal() { echo "$REF_ROOT/journal/$1"; }
ref_anchor()  { echo "$REF_ROOT/anchors/$1"; }

empty_tree()  { git hash-object -t tree /dev/null; }

current_tip() { git rev-parse --verify "$1" 2>/dev/null || true; }

ff_update() {
  local ref="$1" new="$2" old="$3" msg="${4:-append shiplog entry}"
  git update-ref -m "$msg" "$ref" "$new" "${old:-0000000000000000000000000000000000000000}"
}

sign_commit() {
  local tree="$1"; shift
  # stdin should be the commit message
  GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-${SHIPLOG_AUTHOR_NAME:-$(git config user.name || echo 'Shiplog Bot')}}"
  GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-${SHIPLOG_AUTHOR_EMAIL:-$(git config user.email || echo 'shiplog-bot@local')}}"
  local signer_flag=()
  case "${SHIPLOG_SIGN:-1}" in
    0|false|no|off) ;; 
    *) signer_flag=(-S) ;;
  esac
  GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL" \
  git commit-tree "$tree" "$@" "${signer_flag[@]}"
}

fmt_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Compose a readable message with optional JSON trailer
compose_message() {
  local env="$1" service="$2" status="$3" reason="$4" ticket="$5" region="$6" cluster="$7" ns="$8" start_ts="$9" end_ts="${10}" dur_s="${11}" repo_head="${12}" artifact="${13}" run_url="${14}"
  cat <<EOF
Deploy: $service $artifact → $env/${region:-?}/${cluster:-?}/${ns:-?}
Reason: ${reason:-"—"} ${ticket:+($ticket)}
Status: ${status^^} (${dur_s}s) @ $(fmt_ts)
Author: ${GIT_AUTHOR_EMAIL:-$(git config user.email || echo 'unknown')}
Repo:   ${repo_head}

---  # optional structured trailer for machines
{"env":"$env","ts":"$(fmt_ts)","who":{"email":"${GIT_AUTHOR_EMAIL:-}","name":"${GIT_AUTHOR_NAME:-}"},"what":{"service":"$service","repo_head":"$repo_head","artifact":"$artifact"},"where":{"region":"$region","cluster":"$cluster","namespace":"$ns"},"why":{"reason":"$reason","ticket":"$ticket"},"how":{"run_url":"$run_url"},"status":"$status","when":{"start_ts":"$start_ts","end_ts":"$end_ts","dur_s":$dur_s}}
EOF
}

ensure_signed_on_verify() {
  local commit="$1"

  case "${SHIPLOG_SIGN:-1}" in
    0|false|no|off) return 0 ;;
  esac

  if ! git cat-file commit "$commit" | grep -q '^gpgsig '; then
    return 1
  fi

  # Prefer SSH allowed signers if configured; otherwise fall back to gpg trust db
  if [ -f "$ALLOWED_SIGNERS_FILE" ]; then
    GIT_SSH_ALLOWED_SIGNERS="$ALLOWED_SIGNERS_FILE" git verify-commit "$commit" >/dev/null 2>&1 \
      || return 1
  else
    git verify-commit "$commit" >/dev/null 2>&1 || return 1
  fi
  return 0
}

author_allowed() {
  local author="$1"
  [ -z "$AUTHOR_ALLOWLIST" ] && return 0
  for a in $AUTHOR_ALLOWLIST; do
    [ "$a" = "$author" ] && return 0
  done
  return 1
}

attach_note_if_present() {
  local commit="$1" log_path="${2:-}"
  [ -z "${log_path}" ] && return 0
  git notes --ref="$NOTES_REF" add -F "$log_path" "$commit"
}

pretty_ls() {
  local ref="$1" limit="$2"
  # Extract quick details from message header + trailers
  local rows=""
  while IFS= read -r c; do
    local subj author date status service env
    author="$(git show -s --format='%ae' "$c")"
    date="$(git show -s --format='%cs' "$c")"
    subj="$(git show -s --format='%s' "$c")"
    # Grep simple keys from body (cheap; resilient if JSON missing)
    status="$(git show -s --format=%B "$c" | awk -F': ' '/^Status: /{print $2; exit}' )"
    service="$(echo "$subj" | awk '{print $2}')"
    env="$(echo "$subj" | awk '{print $4}' | awk -F'→' '{print $2}' | awk -F'/' '{print $1}')"
    rows+="$c\t${status:-?}\t${service:-?}\t${env:-?}\t$author\t$date"$'\n'
  done < <(git rev-list --max-count="$limit" "$ref")
  printf "%s" "$rows" | $GUM table --columns "Commit" "Status" "Service" "Env" "Author" "Date"
}

show_entry() {
  local target="$1"
  local body
  body="$(git show -s --format=%B "$target")"
  # Split human header from JSON trailer if present
  local human json
  human="$(awk '/^---/{exit} {print}' <<< "$body")"
  json="$(awk '/^---/{flag=1;next}flag' <<< "$body")"

  $GUM style --border normal --margin "0 0 1 0" --padding "1 2" --title "SHIPLOG Entry" -- "$human"

  if [ -n "$json" ]; then
    if command -v jq >/dev/null 2>&1; then
      echo "$json" | jq . | $GUM style --border rounded --title "Structured Trailer (JSON)"
    else
      echo "$json" | $GUM style --border rounded --title "Structured Trailer (raw)"
    fi
  fi

  # Show note if exists
  if git notes --ref="$NOTES_REF" show "$target" >/dev/null 2>&1; then
    git notes --ref="$NOTES_REF" show "$target" | $GUM style --border rounded --title "Attached Log (notes)"
  fi
}

ensure_in_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Run inside a git repo."
  git rev-parse HEAD >/dev/null 2>&1 || die "Repo must have at least one commit (HEAD)."
}

# -------- Commands --------
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

  # Interactive prompt with gum (defaults can be passed via envs)
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

  # Optional: attach a log file if SHIPLOG_LOG is set
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

usage() {
  cat <<EOF
SHIPLOG-Lite
Usage:
  $(basename "$0") init
  $(basename "$0") write [ENV]
  $(basename "$0") ls   [ENV] [LIMIT]
  $(basename "$0") show [COMMIT|default: refs/_shiplog/journal/$DEFAULT_ENV]
  $(basename "$0") verify [ENV]
  $(basename "$0") export-json [ENV]

Env via $SHIPLOG_ENV (default: $DEFAULT_ENV). Optional vars: SHIPLOG_* (author, image, tag, run url, log).
EOF
}

# -------- Main --------
sub="${1:-}"; shift || true
case "$sub" in
  init)          cmd_init "$@";;
  write)         cmd_write "$@";;
  ls)            cmd_ls "$@";;
  show)          cmd_show "$@";;
  verify)        cmd_verify "$@";;
  export-json)   cmd_export_json "$@";;
  *)             usage; exit 1;;
esac
