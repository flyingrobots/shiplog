#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_install_cli
  export SHIPLOG_SIGN=0
  export SHIPLOG_ENV="prod"
  export SHIPLOG_SERVICE="ui"
  run bash -lc 'git shiplog --yes write'
  [ "$status" -eq 0 ]
}

@test "git shiplog show (no args) shows latest entry" {
  run git shiplog show
  [ "$status" -eq 0 ]
  [[ "$output" == *"SHIPLOG Entry"* ]]
  [[ "$output" == *"Deploy:"* ]]
}
