#!/usr/bin/env bash

shiplog_install_cli() {
  SHIPLOG_HOME="${SHIPLOG_HOME:-/workspace}"

  if [[ ! -f "${SHIPLOG_HOME}/bin/git-shiplog" ]]; then
    echo "ERROR: Source file ${SHIPLOG_HOME}/bin/git-shiplog does not exist!" >&2
    return 1
  fi

  if [[ ! -x "${SHIPLOG_HOME}/bin/git-shiplog" ]]; then
    echo "ERROR: Source file ${SHIPLOG_HOME}/bin/git-shiplog is not executable!" >&2
    return 1
  fi

  if ! install -m 0755 "${SHIPLOG_HOME}/bin/git-shiplog" /usr/local/bin/git-shiplog; then
    echo "ERROR: Failed to install git-shiplog binary!" >&2
    return 1
  fi
}
