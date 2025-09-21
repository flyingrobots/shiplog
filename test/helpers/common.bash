#!/usr/bin/env bash

shiplog_install_cli() {
  export SHIPLOG_HOME="${SHIPLOG_HOME:-/workspace}"

  if [[ ! -f /workspace/bin/git-shiplog ]]; then
    echo "ERROR: Source file /workspace/bin/git-shiplog does not exist!" >&2
    return 1
  fi

  if [[ ! -x /workspace/bin/git-shiplog ]]; then
    echo "ERROR: Source file /workspace/bin/git-shiplog is not executable!" >&2
    return 1
  fi

  install -m 0755 /workspace/bin/git-shiplog /usr/local/bin/git-shiplog

  if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to install git-shiplog binary!" >&2
    return 1
  fi
}
