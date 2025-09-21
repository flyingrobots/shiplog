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

    curl -fsSLo "$tmpdir/$asset" "$base_url/$asset"
    curl -fsSLo "$tmpdir/$checksum_file" "$base_url/$checksum_file"

    checksum=$(awk -v f="$asset" '$2 == f { print $1 }' "$tmpdir/$checksum_file")
    [ -n "$checksum" ] || die "unable to locate checksum for $asset in $checksum_file"

    echo "$checksum  $tmpdir/$asset" | sha256sum -c -

    install -m 0644 "$tmpdir/$asset" "$output"
    ;;
  *)
    usage
    exit 1
    ;;
esac
