#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: policy/validate.sh [--stdin|-] [policy.json]

Reads a Shiplog policy JSON document (from a file path or STDIN) and emits
validation errors one per line. Returns 0 when the policy is valid, 1 when
errors are present.
USAGE
}

INPUT_MODE="file"
INPUT_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --stdin|-)
      INPUT_MODE="stdin"
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      INPUT_PATH="$1"
      shift
      ;;
  esac
  if [ "$INPUT_MODE" = "stdin" ] && [ -n "$INPUT_PATH" ]; then
    echo "policy/validate.sh: cannot mix --stdin with file argument" >&2
    exit 64
  fi
done

if [ "$INPUT_MODE" = "file" ] && [ -z "$INPUT_PATH" ]; then
  if [ $# -gt 0 ]; then
    INPUT_PATH="$1"
  fi
fi

if [ "$INPUT_MODE" = "file" ] && [ -z "$INPUT_PATH" ]; then
  echo "policy/validate.sh: missing policy JSON path or --stdin" >&2
  exit 64
fi

ROOT_DIR="${SHIPLOG_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FILTER_PATH="${SHIPLOG_POLICY_VALIDATOR:-$ROOT_DIR/scripts/lib/policy_validate.jq}"
if [ ! -f "$FILTER_PATH" ]; then
  echo "policy/validate.sh: validator filter not found at $FILTER_PATH" >&2
  exit 66
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "policy/validate.sh: jq is required" >&2
  exit 127
fi

read_json() {
  if [ "$INPUT_MODE" = "stdin" ]; then
    cat
  else
    cat "$INPUT_PATH"
  fi
}

errors=$(read_json | jq -r -f "$FILTER_PATH" 2>/dev/null || true)
if [ -n "$errors" ]; then
  printf '%s\n' "$errors"
  exit 1
fi
exit 0
