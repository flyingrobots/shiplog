#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SHIPLOG_BIN="$REPO_ROOT/bin/git-shiplog"

if [ -x "$SHIPLOG_BIN" ]; then
  "$SHIPLOG_BIN" --help >/dev/null 2>&1 || echo "WARNING: $SHIPLOG_BIN --help failed during container initialization"
fi
