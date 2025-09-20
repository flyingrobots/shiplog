#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_install_cli
  export SHIPLOG_SIGN=0
  export SHIPLOG_ENV="prod"
  export SHIPLOG_SERVICE="ui"
  run bash -lc 'yes | shiplog write'
  [ "$status" -eq 0 ]
}

@test "shiplog show (no args) shows latest entry" {
  run shiplog show
  [ "$status" -eq 0 ]
  [[ "$output" == *"SHIPLOG Entry"* ]]
  [[ "$output" == *"Deploy:"* ]]
}
