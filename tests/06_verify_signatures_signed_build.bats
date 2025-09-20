#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_install_cli
}

@test "signed commits verify when ENABLE_SIGNING=true image is used" {
  if [ "${ENABLE_SIGNING:-false}" != "true" ]; then
    skip "Built without signing support; set ENABLE_SIGNING=true for this test"
  fi
  export SHIPLOG_SIGN=1
  export SHIPLOG_ENV="signed"
  export SHIPLOG_SERVICE="signed-web"
  run bash -lc 'yes | shiplog write'
  [ "$status" -eq 0 ]
  run shiplog verify
  [ "$status" -eq 0 ]
}
