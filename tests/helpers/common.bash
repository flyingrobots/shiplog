#!/usr/bin/env bash

shiplog_install_cli() {
  export SHIPLOG_HOME="${SHIPLOG_HOME:-/workspace}"
  install -m 0755 /workspace/bin/shiplog /usr/local/bin/shiplog
}
