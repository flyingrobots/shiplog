# Git-interaction helpers

ref_journal() { echo "$REF_ROOT/journal/$1"; }
ref_anchor()  { echo "$REF_ROOT/anchors/$1"; }

empty_tree()  { git hash-object -t tree /dev/null; }

current_tip() { git rev-parse --verify "$1" 2>/dev/null || true; }

ff_update() {
  local ref="$1" new="$2" old="$3" msg="${4:-append shiplog entry}"
  git update-ref -m "$msg" "$ref" "$new" "${old:-0000000000000000000000000000000000000000}"
}

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

sign_commit() {
  local tree="$1"; shift
  resolve_policy
  local sign_mode="${SHIPLOG_SIGN_EFFECTIVE:-1}"
  GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-${SHIPLOG_AUTHOR_NAME:-$(git config user.name || echo 'Shiplog Bot')}}"
  GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-${SHIPLOG_AUTHOR_EMAIL:-$(git config user.email || echo 'shiplog-bot@local')}}"
  local signer_flag=()
  case "$sign_mode" in
    0|false|no|off) ;;
    *) signer_flag=(-S) ;;
  esac
  GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL" \
    git commit-tree "$tree" "$@" "${signer_flag[@]}"
}

attach_note_if_present() {
  local commit="$1" log_path="${2:-}"
  [ -z "${log_path}" ] && return 0
  git notes --ref="$NOTES_REF" add -F "$log_path" "$commit"
}

ensure_signed_on_verify() {
  local commit="$1"
  resolve_policy

  case "${SHIPLOG_SIGN_EFFECTIVE:-1}" in
    0|false|no|off) return 0 ;;
  esac

  if ! git cat-file commit "$commit" | grep -q '^gpgsig '; then
    return 1
  fi

  local verify_file="$SIGNERS_FILE_EFFECTIVE"
  if [ -n "$verify_file" ] && [ -f "$verify_file" ]; then
    GIT_SSH_ALLOWED_SIGNERS="$verify_file" git verify-commit "$commit" >/dev/null 2>&1 \
      || return 1
  else
    git verify-commit "$commit" >/dev/null 2>&1 || return 1
  fi
  return 0
}

author_allowed() {
  resolve_policy
  local author="$1"
  local allow="$ALLOWED_AUTHORS_EFFECTIVE"
  [ -z "$allow" ] && return 0
  for a in $allow; do
    [ "$a" = "$author" ] && return 0
  done
  return 1
}

require_allowed_author() {
  resolve_policy
  local allow="$ALLOWED_AUTHORS_EFFECTIVE"
  [ -z "$allow" ] && return 0

  local email
  if [ -n "${GIT_AUTHOR_EMAIL:-}" ]; then
    email="$GIT_AUTHOR_EMAIL"
  elif [ -n "${SHIPLOG_AUTHOR_EMAIL:-}" ]; then
    email="$SHIPLOG_AUTHOR_EMAIL"
  else
    email="$(git config user.email || echo)"
  fi

  if [ -z "$email" ]; then
    die "shiplog: unable to determine author email for allowlist enforcement"
  fi

  for a in $allow; do
    [ "$a" = "$email" ] && return 0
  done

  die "shiplog: author <$email> not in allowlist: $allow"
}

require_allowed_signer() {
  resolve_policy
  case "${SHIPLOG_SIGN_EFFECTIVE:-1}" in
    0|false|no|off) return 0 ;;
  esac

  local asf="$SIGNERS_FILE_EFFECTIVE"
  [ -n "$asf" ] && [ -f "$asf" ] || return 0

  local tree tmp
  tree=$(empty_tree)
  if ! tmp=$(printf 'shiplog: signing precheck\n' |
    GIT_AUTHOR_NAME='Shiplog Precheck' \
    GIT_AUTHOR_EMAIL='shiplog-precheck@local' \
    GIT_COMMITTER_NAME='Shiplog Precheck' \
    GIT_COMMITTER_EMAIL='shiplog-precheck@local' \
    git commit-tree "$tree" -S); then
    die "shiplog: signing precheck failed (configure your signing key)"
  fi

  if ! GIT_SSH_ALLOWED_SIGNERS="$asf" git verify-commit "$tmp" >/dev/null 2>&1; then
    die "shiplog: signature not accepted by allowed signers file ($asf)"
  fi
}

pretty_ls() {
  local ref="$1" limit="$2"
  local rows=""
  while IFS= read -r c; do
    local subj author date status service env
    author="$(git show -s --format='%ae' "$c")"
    date="$(git show -s --format='%cs' "$c")"
    subj="$(git show -s --format='%s' "$c")"
    status="$(git show -s --format=%B "$c" | awk -F': ' '/^Status: /{print $2; exit}')"
    service="$(echo "$subj" | awk '{print $2}')"
    env="$(echo "$subj" | awk '{print $4}' | awk -F'→' '{print $2}' | awk -F'/' '{print $1}')"
    rows+="$c\t${status:-?}\t${service:-?}\t${env:-?}\t$author\t$date"$'\n'
  done < <(git rev-list --max-count="$limit" "$ref")
  printf "%s" "$rows" | $GUM table --separator $'\t' --columns "Commit" "Status" "Service" "Env" "Author" "Date"
}

show_entry() {
  local target="$1"
  local body
  body="$(git show -s --format=%B "$target")"
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

  if git notes --ref="$NOTES_REF" show "$target" >/dev/null 2>&1; then
    git notes --ref="$NOTES_REF" show "$target" | $GUM style --border rounded --title "Attached Log (notes)"
  fi
}

ensure_in_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Run inside a git repo."
  git rev-parse HEAD >/dev/null 2>&1 || die "Repo must have at least one commit (HEAD)."
}
