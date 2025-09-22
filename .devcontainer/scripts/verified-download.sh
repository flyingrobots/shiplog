#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage: Securely download and verify files using SHA-256 checksums
  verified-download.sh simple <base-url> <asset> <checksum-file> <output-path>

Arguments:
  base-url      Base URL to download from
  asset         File to download
  checksum-file File containing SHA-256 checksums
  output-path   Relative path where to save the file
USAGE
}

die() {
  printf 'verified-download: ERROR: %s\n' "$*" >&2
  exit 1
}

resolve_base_dir() {
  local base="$1"
  (
    cd "$base" 2>/dev/null && pwd -P
  )
}

validate_output_path() {
  local raw="$1"

  case "$raw" in
    /*) die "output path must be relative" ;;
  esac

  local base="${VERIFIED_DOWNLOAD_BASE:-$PWD}"
  local resolved_base
  resolved_base=$(resolve_base_dir "$base") || die "unable to resolve base directory"

  IFS='/' read -r -a segments <<< "$raw"
  local -a cleaned=()
  local part
  for part in "${segments[@]}"; do
    case "$part" in
      ''|'.')
        continue
        ;;
      '..')
        die "output path must not contain .. segments"
        ;;
    esac
    cleaned+=("$part")
  done

  local target="$resolved_base"
  for part in "${cleaned[@]}"; do
    target="$target/$part"
    if [ -L "$target" ]; then
      die "output path traverses symbolic link: $target"
    fi
  done

  printf '%s\n' "$target"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found"
}

mode=${1:-}
[ -n "$mode" ] || { echo "ERROR: Mode argument required" >&2; usage; exit 1; }
shift || true

case "$mode" in
  simple)
    [ $# -eq 4 ] || { echo "ERROR: Simple mode requires exactly 4 arguments, got $#" >&2; usage; exit 1; }
    require_cmd curl
    require_cmd sha256sum
    base_url="$1"
    asset="$2"
    checksum_file="$3"
    output="$4"
    resolved_output=$(validate_output_path "$output")

    tmpdir="$(mktemp -d)" || die "failed to create temporary directory"
    trap 'rm -rf "$tmpdir"' EXIT

    curl -fsSL --max-time 60 --max-redirs 3 --user-agent "verified-download/1.0" -o "$tmpdir/$asset" "$base_url/$asset" || die "failed to download asset from $base_url/$asset"
    curl -fsSL --max-time 60 --max-redirs 3 --user-agent "verified-download/1.0" -o "$tmpdir/$checksum_file" "$base_url/$checksum_file" || die "failed to download checksum file from $base_url/$checksum_file"

    checksum=$(awk -v f="$asset" '($2 == f || $2 == "*"f) && NF >= 2 { print $1; exit }' "$tmpdir/$checksum_file")
    [ -n "$checksum" ] || die "unable to locate checksum for $asset in $checksum_file"
    [[ "$checksum" =~ ^[a-fA-F0-9]{64}$ ]] || die "invalid SHA-256 checksum format: $checksum"

    (cd "$tmpdir" && echo "$checksum  $asset" | sha256sum -c - >/dev/null)

    mkdir -p "$(dirname "$resolved_output")"
    install -m 0644 "$tmpdir/$asset" "$resolved_output" || die "failed to install $asset to $resolved_output"
    [ -f "$resolved_output" ] || die "installation verification failed: $resolved_output not found"
    ;;
  *)
    usage
    exit 1
    ;;
esac
