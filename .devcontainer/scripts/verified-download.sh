#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage:
  verified-download.sh simple <base-url> <asset> <checksum-file> <output-path>
USAGE
}

die() {
  echo "shiplog: $*" >&2
  exit 1
}

resolve_path_join() {
  local base="$1" rel="$2" interpreter=""
  if command -v python3 >/dev/null 2>&1; then
    interpreter=python3
  elif command -v python >/dev/null 2>&1; then
    interpreter=python
  else
    echo ""; return 1
  fi
  "$interpreter" - <<'PY' "$base" "$rel"
import os, sys
base = os.path.realpath(os.path.expanduser(sys.argv[1]))
rel = sys.argv[2]
print(os.path.realpath(os.path.join(base, rel)))
PY
}

validate_output_path() {
  local raw="$1"
  [[ "$raw" != *$'\0'* ]] || die "output path contains null byte"
  case "$raw" in
    /*) die "output path must be relative" ;;
  esac
  case "$raw" in
    *".."* ) die "output path must not contain .. segments" ;;
  esac

  local base="${VERIFIED_DOWNLOAD_BASE:-$PWD}"
  local resolved_base
  resolved_base=$(resolve_path_join "$base" .) || die "unable to resolve base directory"
  local resolved_output
  resolved_output=$(resolve_path_join "$resolved_base" "$raw") || die "unable to resolve output path"

  case "$resolved_output" in
    "$resolved_base"|"$resolved_base"/*) ;; 
    *) die "output path escapes allowed directory ($resolved_base)" ;;
  esac

  printf '%s' "$resolved_output"
}

mode=${1:-}
[ -n "$mode" ] || { usage; exit 1; }
shift || true

case "$mode" in
  simple)
    [ $# -eq 4 ] || { usage; exit 1; }
    base_url="$1"
    asset="$2"
    checksum_file="$3"
    output="$4"
    resolved_output=$(validate_output_path "$output")

    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT

    curl -fsSL --max-time 60 --max-redirs 3 --user-agent "verified-download/1.0" -o "$tmpdir/$asset" "$base_url/$asset"
    curl -fsSL --max-time 60 --max-redirs 3 --user-agent "verified-download/1.0" -o "$tmpdir/$checksum_file" "$base_url/$checksum_file"

    # Parse checksum more robustly, handle both " " and " *" formats
    checksum=$(awk -v f="$asset" '($2 == f || $2 == "*"f) && NF >= 2 { print $1; exit }' "$tmpdir/$checksum_file")
    [ -n "$checksum" ] || die "unable to locate checksum for $asset in $checksum_file"
    
    # Validate it's actually a SHA-256 hash (64 hex chars)
    [[ "$checksum" =~ ^[a-fA-F0-9]{64}$ ]] || die "invalid SHA-256 checksum format: $checksum"

    # Use safer verification method
    (cd "$tmpdir" && echo "$checksum  $asset" | sha256sum -c -)

    mkdir -p "$(dirname "$resolved_output")"
    install -m 0644 "$tmpdir/$asset" "$resolved_output"
    ;;
  *)
    usage
    exit 1
    ;;
esac
