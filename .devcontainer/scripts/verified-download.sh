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

    install -m 0644 "$tmpdir/$asset" "$output"
    ;;
  *)
    usage
    exit 1
    ;;
esac
