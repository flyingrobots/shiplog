#!/usr/bin/env bash
set -euo pipefail

SHIPLOG_BIN="bin/git-shiplog"
LEGACY_BIN="bin/shiplog"

if [ -x "$SHIPLOG_BIN" ]; then
  "$SHIPLOG_BIN" --help >/dev/null 2>&1 || echo "WARNING: $SHIPLOG_BIN --help failed during container initialization"
elif [ -x "$LEGACY_BIN" ]; then
  "$LEGACY_BIN" --help >/dev/null 2>&1 || echo "WARNING: $LEGACY_BIN --help failed during container initialization"
fi
