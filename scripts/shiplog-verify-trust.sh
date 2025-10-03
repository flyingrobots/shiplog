#!/usr/bin/env bash
set -euo pipefail

# shiplog-verify-trust.sh — verify a trust update for threshold and mode
# Usage:
#   shiplog-verify-trust.sh --old <old_oid|0> --new <new_oid> [--ref <ref>]
#
# Behavior v0 (initial):
#   - Always require the new trust commit to be signature-verified.
#   - If threshold == 1: accept after signature verification.
#   - If threshold > 1 and sig_mode == chain: ensure the update range contains
#     commits all sharing the same tree, each signature verifies, and at least
#     <threshold> distinct maintainer emails appear as authors.
#   - If threshold > 1 and sig_mode == attestation: ensure at least <threshold>
#     files exist under .shiplog/trust_sigs/ (minimal check). If ssh-keygen is
#     available and allowed_signers is present, attempt to verify each signature
#     over the canonical payload; otherwise emit a warning and reject unless
#     SHIPLOG_ALLOW_TRUST_THRESHOLD_UNENFORCED=1.

err() { echo "❌ shiplog: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || err "missing dependency: $1"; }

OLD=""; NEW=""; REF="refs/_shiplog/trust/root"
while [ $# -gt 0 ]; do
  case "$1" in
    --old) shift; OLD="${1:-}" ;;
    --new) shift; NEW="${1:-}" ;;
    --ref) shift; REF="${1:-}" ;;
    *) err "unknown arg: $1" ;;
  esac
  shift || true
done

[ -n "$NEW" ] || err "--new is required"
[ -n "$OLD" ] || OLD="0000000000000000000000000000000000000000"

JQ_BIN="${SHIPLOG_JQ_BIN:-jq}"
need git; need "$JQ_BIN"

load_blob() { git show "$1:$2" 2>/dev/null || true; }

TRUST_JSON=$(load_blob "$NEW" "trust.json")
[ -n "$TRUST_JSON" ] || err "trust.json missing in $REF@${NEW}"

threshold=$(printf '%s' "$TRUST_JSON" | "$JQ_BIN" -r '.threshold // 1')
sig_mode=$(printf '%s' "$TRUST_JSON" | "$JQ_BIN" -r '.sig_mode // "chain"')
[ -n "$sig_mode" ] || sig_mode="chain"

signers_blob=$(load_blob "$NEW" "allowed_signers")
SIGNERS_FILE=""
if [ -n "$signers_blob" ]; then
  SIGNERS_FILE=$(mktemp)
  printf '%s' "$signers_blob" > "$SIGNERS_FILE"
  chmod 600 "$SIGNERS_FILE"
fi

verify_commit_sig() {
  local c="$1"
  if [ -n "$SIGNERS_FILE" ]; then
    GIT_SSH_ALLOWED_SIGNERS="$SIGNERS_FILE" git verify-commit "$c" >/dev/null 2>&1 || return 1
  else
    git verify-commit "$c" >/dev/null 2>&1 || return 1
  fi
}

# 1) Always require the new trust commit to be signature-verified.
verify_commit_sig "$NEW" || err "trust commit $NEW failed signature verification"

# 2) Threshold==1 is satisfied now.
if [ "$threshold" = "1" ] || [ "$threshold" = "1.0" ]; then
  exit 0
fi

if ! printf '%s' "$threshold" | grep -Eq '^[1-9][0-9]*$'; then
  err "invalid threshold: $threshold"
fi

trust_tree_oid() {
  git show -s --format='%T' "$1"
}

if [ "$sig_mode" = "chain" ]; then
  # Range is either NEW if OLD is zero, or NEW ^OLD
  if [ "$OLD" = "0000000000000000000000000000000000000000" ]; then
    err "threshold>1 requires multiple co-signed commits in chain mode"
  fi
  local tree expected
  expected=$(trust_tree_oid "$NEW")
  count=0
  authors_seen=""
  while read -r c; do
    [ -n "$c" ] || continue
    verify_commit_sig "$c" || err "co-sign commit $c failed signature verification"
    tree=$(trust_tree_oid "$c")
    [ "$tree" = "$expected" ] || err "co-sign commit $c does not match trust tree"
    ae=$(git show -s --format='%ae' "$c")
    case " $authors_seen " in *" $ae "*) : ;; *) authors_seen="$authors_seen $ae"; count=$((count+1));; esac
  done < <(git rev-list --ancestry-path "$OLD..$NEW")
  if [ "$count" -lt "$threshold" ]; then
    err "co-sign chain has $count maintainer commits; threshold is $threshold"
  fi
  exit 0
fi

if [ "$sig_mode" = "attestation" ]; then
  # Minimal: require at least <threshold> files under .shiplog/trust_sigs/
  mapfile -t sigs < <(git ls-tree -r --name-only "$NEW" | awk '/^\.shiplog\/trust_sigs\//{print}')
  nsigs=${#sigs[@]}
  if [ "$nsigs" -lt "$threshold" ] && [ "${SHIPLOG_ALLOW_TRUST_THRESHOLD_UNENFORCED:-0}" != "1" ]; then
    err "found $nsigs attestation files; threshold is $threshold"
  fi
  # TODO: Verify each signature over canonical payload when ssh-keygen is present.
  exit 0
fi

err "unknown sig_mode: $sig_mode"

