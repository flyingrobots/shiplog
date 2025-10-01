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

# Enforce a timeout for the Bats test run (set TEST_TIMEOUT_SECS=0 to disable)
TEST_TIMEOUT_SECS="${TEST_TIMEOUT_SECS:-180}"

use_timeout() {
  local val="$1"
  case "$val" in
    ''|0|0s|0S|0sec|0SEC) return 1 ;;
    *[!0-9]*) return 2 ;;
  esac
  [ "$val" -gt 0 ]
}

if ! command -v bats >/dev/null 2>&1; then
  echo "bats is required to run the Shiplog test suite" >&2
  exit 127
fi

timeout_enabled=0
use_timeout "$TEST_TIMEOUT_SECS"
timeout_status=$?
case "$timeout_status" in
  0) timeout_enabled=1 ;;
  1) timeout_enabled=0 ;;
  2)
    echo "shiplog test.sh: TEST_TIMEOUT_SECS must be a positive integer or 0 (got '${TEST_TIMEOUT_SECS}')" >&2
    exit 64
    ;;
esac

if command -v timeout >/dev/null 2>&1; then
  if [ "$timeout_enabled" -eq 1 ]; then
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
else
  if [ "$timeout_enabled" -eq 1 ]; then
    echo "shiplog test.sh: timeout command not found but TEST_TIMEOUT_SECS=${TEST_TIMEOUT_SECS}; install coreutils timeout or set TEST_TIMEOUT_SECS=0" >&2
    exit 64
  fi
  if [ -n "${BATS_FLAGS:-}" ]; then
    bats $BATS_FLAGS "$SHIPLOG_HOME/test"
  else
    bats -r "$SHIPLOG_HOME/test"
  fi
fi
