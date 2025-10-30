#!/usr/bin/env bash
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1; }

mint_id() {
  if need ulid; then
    ulid
    return
  fi
  if need uuidgen; then
    uuidgen | tr 'A-Z' 'a-z'
    return
  fi
  printf 'rel-%s-%s-%06x\n' \
    "$(date -u +%Y%m%dT%H%M%SZ)" \
    "$(git rev-parse --short=8 HEAD 2>/dev/null || echo 00000000)" \
    "$RANDOM$RANDOM"
}

EXPORT=0
ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --id) shift; ID="${1:-}"; shift; continue ;;
    --export|-x) EXPORT=1; shift; continue ;;
    --help|-h) echo "usage: $0 [--id ID] [--export]"; exit 0 ;;
    --) shift; break ;;
    *) echo "❌ unknown option: $1" >&2; exit 2 ;;
  esac
done

[ -n "$ID" ] || ID="$(mint_id)"

if [ "$EXPORT" -eq 1 ]; then
  echo "export SHIPLOG_DEPLOY_ID=$ID"
else
  echo "$ID"
fi

