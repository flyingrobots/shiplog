#!/usr/bin/env bash

shiplog_install_cli() {
  export SHIPLOG_HOME="${SHIPLOG_HOME:-/workspace}"
  export SHIPLOG_LIB_DIR="${SHIPLOG_LIB_DIR:-/workspace/lib}"
  install -m 0755 /workspace/shiplog-lite.sh /usr/local/bin/shiplog
}
