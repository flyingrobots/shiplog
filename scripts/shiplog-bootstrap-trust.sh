#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHIPLOG_HOME="${SHIPLOG_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
cd "$SHIPLOG_HOME"

BOSUN_BIN="${SHIPLOG_BOSUN_BIN:-$SHIPLOG_HOME/scripts/bosun}"
if command -v "$BOSUN_BIN" >/dev/null 2>&1; then
  BOSUN_AVAILABLE=1
else
  if command -v bosun >/dev/null 2>&1; then
    BOSUN_BIN="$(command -v bosun)"
    BOSUN_AVAILABLE=1
  else
    BOSUN_AVAILABLE=0
  fi
fi

usage() {
  cat <<'USAGE'
shiplog-bootstrap-trust.sh

Bootstraps the signer roster for refs/_shiplog/trust/root by gathering maintainer metadata,
writing .shiplog/trust.json and .shiplog/allowed_signers, building the genesis commit, and
(optionally) pushing it to origin.

Usage: shiplog-bootstrap-trust.sh [--force] [--no-push] [--yes] [--plain]

Options:
  --force     overwrite existing trust files or refs/_shiplog/trust/root
  --no-push   generate the trust commit but skip the final git push
  --yes       assume yes for confirmations (or set SHIPLOG_ASSUME_YES=1)
  --plain     disable Bosun UI; use plain prompts (or set SHIPLOG_PLAIN=1)
  -h, --help  show this help and exit
USAGE
}

ASSUME_YES="${SHIPLOG_ASSUME_YES:-0}"
PLAIN_UI="${SHIPLOG_PLAIN:-0}"

prompt_input() {
  local prompt="$1" default="${2:-}" value=""
  if [ "$PLAIN_UI" -ne 1 ] && [ "$BOSUN_AVAILABLE" -eq 1 ] && [ -t 0 ] && [ -t 1 ]; then
    value=$("$BOSUN_BIN" input --placeholder "$prompt" --value "$default")
  else
    if [ -n "$default" ]; then
      printf '%s [%s]: ' "$prompt" "$default"
    else
      printf '%s: ' "$prompt"
    fi
    read -r value || value=""
    if [ -z "$value" ]; then
      value="$default"
    fi
  fi
  printf '%s\n' "$value"
}

prompt_confirm() {
  local prompt="$1" default_yes="${2:-1}"
  if [ "$ASSUME_YES" -eq 1 ]; then
    return 0
  fi
  if [ "$PLAIN_UI" -ne 1 ] && [ "$BOSUN_AVAILABLE" -eq 1 ] && [ -t 0 ] && [ -t 1 ]; then
    if [ "$default_yes" -eq 1 ]; then
      "$BOSUN_BIN" confirm --default-yes "$prompt"
    else
      "$BOSUN_BIN" confirm "$prompt"
    fi
    return $?
  fi
  local fallback
  if [ "$default_yes" -eq 1 ]; then
    printf '%s [Y/n]: ' "$prompt"
    read -r fallback || fallback=""
    case "${fallback:-y}" in
      y|Y|yes|YES) return 0 ;;
      *) return 1 ;;
    esac
  else
    printf '%s [y/N]: ' "$prompt"
    read -r fallback || fallback=""
    case "${fallback:-n}" in
      y|Y|yes|YES) return 0 ;;
      *) return 1 ;;
    esac
  fi
}

die() {
  printf '❌ %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"
}

json_quote() {
  jq -Rn --arg v "$1" '$v'
}

FORCE=0
DO_PUSH=1
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1 ;;
    --no-push) DO_PUSH=0 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --plain) PLAIN_UI=1 ;;
    --no-color) NO_COLOR=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
  shift || true
done

need git
need jq

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  die "run this script inside a git repository"
fi

TRUST_REF="refs/_shiplog/trust/root"
if git show-ref --verify --quiet "$TRUST_REF" && [ "$FORCE" -ne 1 ]; then
  die "$TRUST_REF already exists. Use --force to overwrite it."
fi

# Optional non-interactive mode via env vars

non_interactive_bootstrap="0"
if [ -n "${SHIPLOG_TRUST_COUNT:-}" ]; then
  if printf '%s' "$SHIPLOG_TRUST_COUNT" | grep -Eq '^[1-9][0-9]*$'; then
    non_interactive_bootstrap="1"
  else
    die "SHIPLOG_TRUST_COUNT must be a positive integer"
  fi
fi

trust_id=""
declare -a maint_names maint_emails maint_roles maint_fprs maint_revoked maint_principals maint_keys
threshold=""
commit_message=""

if [ "$non_interactive_bootstrap" = "1" ]; then
  trust_id="${SHIPLOG_TRUST_ID:-shiplog-trust-root}"
  count="$SHIPLOG_TRUST_COUNT"
  i=1
  while [ "$i" -le "$count" ]; do
    name_var="SHIPLOG_TRUST_${i}_NAME"
    email_var="SHIPLOG_TRUST_${i}_EMAIL"
    role_var="SHIPLOG_TRUST_${i}_ROLE"
    fpr_var="SHIPLOG_TRUST_${i}_PGP_FPR"
    key_path_var="SHIPLOG_TRUST_${i}_SSH_KEY_PATH"
    principal_var="SHIPLOG_TRUST_${i}_PRINCIPAL"
    revoked_var="SHIPLOG_TRUST_${i}_REVOKED"

    eval name_val="\${$name_var:-}"
    eval email_val="\${$email_var:-}"
    eval role_val="\${$role_var:-root}"
    eval fpr_val="\${$fpr_var:-}"
    eval key_path_val="\${$key_path_var:-}"
    eval principal_val="\${$principal_var:-}"
    eval revoked_val="\${$revoked_var:-no}"

    [ -n "$name_val" ]   || die "missing $name_var"
    [ -n "$email_val" ]  || die "missing $email_var"
    [ -n "$key_path_val" ] || die "missing $key_path_var (path to SSH .pub)"
    [ -r "$key_path_val" ] || die "cannot read SSH key: $key_path_val"
    key_line=$(awk 'NR==1 {print; exit}' "$key_path_val")
    [ -n "$key_line" ] || die "empty SSH key: $key_path_val"
    if [ -z "$principal_val" ]; then
      principal_val="$email_val"
    fi
    case "$revoked_val" in
      y|Y|yes|YES|true|TRUE|1) revoked_val=true ;;
      *) revoked_val=false ;;
    esac

    maint_names+=("$name_val")
    maint_emails+=("$email_val")
    maint_roles+=("$role_val")
    maint_fprs+=("$fpr_val")
    maint_revoked+=("$revoked_val")
    maint_principals+=("$principal_val")
    maint_keys+=("$key_line")
    i=$((i+1))
  done
  threshold="${SHIPLOG_TRUST_THRESHOLD:-$count}"
  if ! printf '%s' "$threshold" | grep -Eq '^[1-9][0-9]*$' || [ "$threshold" -gt "$count" ]; then
    die "invalid SHIPLOG_TRUST_THRESHOLD: $threshold (count=$count)"
  fi
  commit_message="${SHIPLOG_TRUST_COMMIT_MESSAGE:-shiplog: trust root v1 (GENESIS)}"
else
  if ! prompt_confirm "Proceed with interactive trust bootstrap?" 1; then
    echo "Aborted." >&2
    exit 1
  fi

  maint_count=""
  while :; do
    maint_count=$(prompt_input "Number of maintainers" "2")
    if printf '%s' "$maint_count" | grep -Eq '^[1-9][0-9]*$'; then
      break
    fi
    echo "Please enter a positive integer." >&2
  done

  trust_id=$(prompt_input "Trust identifier" "shiplog-trust-root")

  index=1
  while [ "$index" -le "$maint_count" ]; do
    echo "--- Maintainer $index ---"
    name=""
    while [ -z "$name" ]; do
      name=$(prompt_input "Full name" "")
      [ -n "$name" ] || echo "Name cannot be empty" >&2
    done

    email=""
    while [ -z "$email" ]; do
      email=$(prompt_input "Email address" "")
      [ -n "$email" ] || echo "Email cannot be empty" >&2
    done

    role=$(prompt_input "Role" "root")
    fpr=$(prompt_input "OpenPGP fingerprint (optional)" "")

    key_line=""
    while [ -z "$key_line" ]; do
      key_path=$(prompt_input "SSH public key path" "")
      if [ -z "$key_path" ]; then
        echo "Path cannot be empty" >&2
        continue
      fi
      if [ ! -f "$key_path" ]; then
        echo "File not found: $key_path" >&2
        continue
      fi
      key_line=$(awk 'NR==1 {print; exit}' "$key_path")
      if [ -z "$key_line" ]; then
        echo "Unable to read SSH key from $key_path" >&2
      fi
    done

    principal=""
    while [ -z "$principal" ]; do
      principal=$(prompt_input "Signer principal" "$email")
      [ -n "$principal" ] || echo "Principal cannot be empty" >&2
    done

    revoked_answer=$(prompt_input "Revoked? (yes/no)" "no")
    case "$revoked_answer" in
      y|Y|yes|YES|true|TRUE) revoked=true ;;
      *) revoked=false ;;
    esac

    maint_names+=("$name")
    maint_emails+=("$email")
    maint_roles+=("$role")
    maint_fprs+=("$fpr")
    maint_revoked+=("$revoked")
    maint_principals+=("$principal")
    maint_keys+=("$key_line")

    index=$((index + 1))
  done

  threshold=""
  while :; do
    threshold=$(prompt_input "Signature threshold" "$maint_count")
    if printf '%s' "$threshold" | grep -Eq '^[1-9][0-9]*$'; then
      if [ "$threshold" -le "$maint_count" ]; then
        break
      fi
      echo "Threshold cannot exceed maintainer count ($maint_count)." >&2
    else
      echo "Please enter a positive integer." >&2
    fi
  done

  commit_message=$(prompt_input "Trust genesis commit message" "shiplog: trust root v1 (GENESIS)")
fi

maint_count=""
while :; do
  maint_count=$(prompt_input "Number of maintainers" "2")
  if printf '%s' "$maint_count" | grep -Eq '^[1-9][0-9]*$'; then
    break
  fi
  echo "Please enter a positive integer." >&2
done

# End non-interactive/interactive branching

summary="Trust ID: $trust_id\nThreshold: $threshold\nMaintainers:"
for i in "${!maint_names[@]}"; do
  summary+=$'\n  - '
  summary+="${maint_names[$i]} <${maint_emails[$i]}> (role: ${maint_roles[$i]}, revoked: ${maint_revoked[$i]})"
done

if [ "$BOSUN_AVAILABLE" -eq 1 ] && [ -t 0 ] && [ -t 1 ]; then
  "$BOSUN_BIN" style --title "Trust Bootstrap" -- "$summary"
else
  printf '\n%s\n\n' "$summary"
fi

if ! prompt_confirm "Continue with these settings?" 1; then
  echo "Aborted." >&2
  exit 1
fi

mkdir -p "$SHIPLOG_HOME/.shiplog"
trust_path="$SHIPLOG_HOME/.shiplog/trust.json"
signers_path="$SHIPLOG_HOME/.shiplog/allowed_signers"

if [ -e "$trust_path" ] && [ "$FORCE" -ne 1 ]; then
  prompt_confirm "Overwrite existing $trust_path?" 0 || die "Refusing to overwrite $trust_path"
fi

if [ -e "$signers_path" ] && [ "$FORCE" -ne 1 ]; then
  prompt_confirm "Overwrite existing $signers_path?" 0 || die "Refusing to overwrite $signers_path"
fi

maintainers_json=""
for i in "${!maint_names[@]}"; do
  name_q=$(json_quote "${maint_names[$i]}" | tr -d '\n')
  email_q=$(json_quote "${maint_emails[$i]}" | tr -d '\n')
  role_q=$(json_quote "${maint_roles[$i]}" | tr -d '\n')
  if [ -n "${maint_fprs[$i]}" ]; then
    fpr_q=$(json_quote "${maint_fprs[$i]}" | tr -d '\n')
  else
    fpr_q="null"
  fi
  revoked_val="${maint_revoked[$i]}"
  maint_json="    {\n      \"name\": $name_q,\n      \"email\": $email_q,\n      \"pgp_fpr\": $fpr_q,\n      \"role\": $role_q,\n      \"revoked\": $revoked_val\n    }"
  if [ -n "$maintainers_json" ]; then
    maintainers_json+=$',\n'
  fi
  maintainers_json+="$maint_json"
done

trust_id_q=$(json_quote "$trust_id" | tr -d '\n')
cat > "$trust_path" <<JSON_DOC
{
  "version": 1,
  "id": $trust_id_q,
  "threshold": $threshold,
  "maintainers": [
$maintainers_json
  ]
}
JSON_DOC

tmp_signers=""
for i in "${!maint_principals[@]}"; do
  tmp_signers+="${maint_principals[$i]} ${maint_keys[$i]}"$'\n'
done
printf '%s' "$tmp_signers" > "$signers_path"

OID_TRUST=$(git hash-object -w "$trust_path")
OID_SIGS=$(git hash-object -w "$signers_path")
TREE=$(printf '100644 blob %s\ttrust.json\n100644 blob %s\tallowed_signers\n' "$OID_TRUST" "$OID_SIGS" | git mktree)

AUTHOR_NAME="${GIT_AUTHOR_NAME:-$(git config user.name || echo "Shiplog Trust")}" \
AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-$(git config user.email || echo "trust@local")}" \
COMMITTER_NAME="${GIT_COMMITTER_NAME:-$AUTHOR_NAME}" \
COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$AUTHOR_EMAIL}"

if [ -z "$AUTHOR_NAME" ] || [ -z "$AUTHOR_EMAIL" ]; then
  die "git config user.name and user.email are required to sign the trust commit"
fi

sign_log="$SHIPLOG_HOME/.shiplog/trust-signing.log"
if ! GENESIS=$(printf '%s\n' "$commit_message" |
  GIT_AUTHOR_NAME="$AUTHOR_NAME" \
  GIT_AUTHOR_EMAIL="$AUTHOR_EMAIL" \
  GIT_COMMITTER_NAME="$COMMITTER_NAME" \
  GIT_COMMITTER_EMAIL="$COMMITTER_EMAIL" \
  git commit-tree "$TREE" -S 2>"$sign_log"); then
  cat "$sign_log" >&2
  rm -f "$sign_log"
  die "failed to sign trust commit; ensure git signing is configured"
fi
rm -f "$sign_log"

git update-ref "$TRUST_REF" "$GENESIS"

printf '✅ Wrote %s and %s\n' "$trust_path" "$signers_path"
printf '✅ Created trust commit %s\n' "$GENESIS"

if [ "$DO_PUSH" -eq 1 ]; then
  if prompt_confirm "Push $TRUST_REF to origin now?" 1; then
    git push origin "$TRUST_REF"
  else
    echo "Skipped push; run 'git push origin $TRUST_REF' when ready." >&2
  fi
else
  echo "Skipping push as requested (use git push when ready)."
fi

echo "Run ./scripts/shiplog-trust-sync.sh to distribute the allowed signers file on other machines."
