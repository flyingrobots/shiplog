#!/usr/bin/env bash
set -euo pipefail

if [ ! -f /.dockerenv ] && ! grep -qE '(docker|containerd|kubepods)' /proc/1/cgroup 2>/dev/null; then
  echo "RUN THESE ONLY IN DOCKER YOU FOOL" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SHIPLOG_HOME="${SHIPLOG_HOME:-$ROOT_DIR}"
export SHIPLOG_LIB_DIR="${SHIPLOG_LIB_DIR:-$SHIPLOG_HOME/lib}"
export SHIPLOG_REF_ROOT="${SHIPLOG_REF_ROOT:-refs/_shiplog}"
export SHIPLOG_NOTES_REF="${SHIPLOG_NOTES_REF:-refs/_shiplog/notes/logs}"
export PATH="$SHIPLOG_HOME/bin:$PATH"

# Avoid network during tests by default; use local sandbox init
export SHIPLOG_USE_LOCAL_SANDBOX="${SHIPLOG_USE_LOCAL_SANDBOX:-1}"

# Optional timeout for the Bats test run (set TEST_TIMEOUT_SECS>0 to enable)
TEST_TIMEOUT_SECS="${TEST_TIMEOUT_SECS:-}"

use_timeout() {
  local val="$1"
  case "$val" in
    ''|0|0s|0S|0sec|0SEC) return 1 ;;
    *[!0-9]*) return 1 ;;
  esac
  [ "$val" -gt 0 ] 2>/dev/null
}

if ! command -v bats >/dev/null 2>&1; then
  echo "bats is required to run the Shiplog test suite" >&2
  exit 127
fi

if command -v timeout >/dev/null 2>&1 && use_timeout "$TEST_TIMEOUT_SECS"; then
  if [ -n "${BATS_FLAGS:-}" ]; then
    timeout "${TEST_TIMEOUT_SECS}s" bats $BATS_FLAGS "$SHIPLOG_HOME/test"
  else
    timeout "${TEST_TIMEOUT_SECS}s" bats -r "$SHIPLOG_HOME/test"
  fi
else
  if [ -n "${BATS_FLAGS:-}" ]; then
    bats $BATS_FLAGS "$SHIPLOG_HOME/test"
  else
    bats -r "$SHIPLOG_HOME/test"
  fi
fi
