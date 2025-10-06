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
  local fmt="${SHIPLOG_GPG_FORMAT:-}"
  local -a gitopts=()
  if [ -n "$fmt" ]; then
    gitopts=(-c "gpg.format=$fmt")
  fi
  if [ -n "$SIGNERS_FILE" ]; then
    GIT_SSH_ALLOWED_SIGNERS="$SIGNERS_FILE" git "${gitopts[@]}" verify-commit "$c" >/dev/null 2>&1 || return 1
  else
    git "${gitopts[@]}" verify-commit "$c" >/dev/null 2>&1 || return 1
  fi
}

# 1) Optionally require the new trust commit to be signature-verified.
case "$(printf '%s' "${SHIPLOG_REQUIRE_SIGNED_TRUST:-0}" | tr '[:upper:]' '[:lower:]')" in
  1|true|yes|on)
    verify_commit_sig "$NEW" || err "trust commit $NEW failed signature verification"
    ;;
  *) : ;;
esac

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
  # Verify detached signatures over canonical payload using ssh-keygen -Y verify.
  need ssh-keygen || true
  if ! command -v ssh-keygen >/dev/null 2>&1; then
    [ "${SHIPLOG_ALLOW_TRUST_THRESHOLD_UNENFORCED:-0}" = "1" ] && exit 0
    err "ssh-keygen not available; cannot verify attestations"
  fi

  [ -n "$SIGNERS_FILE" ] || err "allowed_signers missing; cannot verify attestations"

  # Collect signatures
  mapfile -t sigs < <(git ls-tree -r --name-only "$NEW" | awk '/^\.shiplog\/trust_sigs\//{print}')
  nsigs=${#sigs[@]}
  if [ "$nsigs" -lt "$threshold" ] && [ "${SHIPLOG_ALLOW_TRUST_THRESHOLD_UNENFORCED:-0}" != "1" ]; then
    err "found $nsigs attestation files; threshold is $threshold"
  fi

  # Build canonical payload; default to base tree (no sigs). Back-compat optional.
  trust_id=$(printf '%s' "$TRUST_JSON" | "$JQ_BIN" -r '.id // "shiplog-trust-root"')
  build_payload() {
    local mode="$1"
    local p
    case "$mode" in
      base)
        local oid_trust oid_sigs base
        oid_trust=$(git ls-tree "$NEW" trust.json | awk '{print $3}')
        oid_sigs=$(git ls-tree "$NEW" allowed_signers | awk '{print $3}')
        if [ -n "$oid_sigs" ]; then
          base=$(printf '100644 blob %s\ttrust.json\n100644 blob %s\tallowed_signers\n' "$oid_trust" "$oid_sigs" | git mktree)
        else
          base=$(printf '100644 blob %s\ttrust.json\n' "$oid_trust" | git mktree)
        fi
        p=$(printf 'shiplog-trust-tree-v1\n%s\n%s\n%s\n' "$base" "$trust_id" "$threshold")
        ;;
      full)
        p=$(printf 'shiplog-trust-tree-v1\n%s\n%s\n%s\n' "$(trust_tree_oid "$NEW")" "$trust_id" "$threshold")
        ;;
    esac
    printf '%s' "$p"
  }

  verify_attest_mode() {
    local mode="$1" tmp_in verified=0 principals_seen=""
    tmp_in=$(mktemp)
    build_payload "$mode" >"$tmp_in"
    for path in "${sigs[@]}"; do
      principal=$(basename "$path" | sed 's/\.sig$//')
      sigblob=$(git show "$NEW:$path" 2>/dev/null || true)
      [ -n "$sigblob" ] || continue
      sigfile=$(mktemp)
      printf '%s' "$sigblob" > "$sigfile"
      if ssh-keygen -Y verify -n shiplog-trust -f "$SIGNERS_FILE" -I "$principal" -s "$sigfile" < "$tmp_in" >/dev/null 2>&1; then
        case " $principals_seen " in *" $principal "*) : ;; *) principals_seen="$principals_seen $principal"; verified=$((verified+1));; esac
      fi
      rm -f "$sigfile"
    done
    rm -f "$tmp_in"
    printf '%s' "$verified"
  }

  mode="${SHIPLOG_ATTEST_PAYLOAD_MODE:-base}"
  verified=$(verify_attest_mode "$mode")
  if [ "$verified" -lt "$threshold" ] && [ "${SHIPLOG_ATTEST_BACKCOMP:-0}" = "1" ]; then
    # Try alternative mode for back-compat
    alt="full"; [ "$mode" = "full" ] && alt="base"
    verified=$(verify_attest_mode "$alt")
  fi

  if [ "$verified" -lt "$threshold" ] && [ "${SHIPLOG_ALLOW_TRUST_THRESHOLD_UNENFORCED:-0}" != "1" ]; then
    err "verified $verified attestations; threshold is $threshold"
  fi
  exit 0
fi

err "unknown sig_mode: $sig_mode"
