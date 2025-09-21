#!/usr/bin/env bash

shiplog_install_cli() {
  export SHIPLOG_HOME="${SHIPLOG_HOME:-/workspace}"

  if [[ ! -f /workspace/bin/shiplog ]]; then
    echo "ERROR: Source file /workspace/bin/shiplog does not exist!" >&2
    return 1
  fi

  if [[ ! -x /workspace/bin/shiplog ]]; then
    echo "ERROR: Source file /workspace/bin/shiplog is not executable!" >&2
    return 1
  fi

  install -m 0755 /workspace/bin/shiplog /usr/local/bin/shiplog

  if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to install shiplog binary!" >&2
    return 1
  fi
}
