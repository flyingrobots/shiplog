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

if ! command -v bats >/dev/null 2>&1; then
  echo "bats is required to run the Shiplog test suite" >&2
  exit 127
fi

bats -r "$SHIPLOG_HOME/test"
