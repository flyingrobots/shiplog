#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_SIGN=0
  export SHIPLOG_ENV="prod"
  export SHIPLOG_SERVICE="ui"
  export SHIPLOG_AUTO_PUSH=0
  run bash -lc 'git shiplog --yes write'
  [ "$status" -eq 0 ]
}

teardown() {
  shiplog_standard_teardown
  unset SHIPLOG_SIGN SHIPLOG_ENV SHIPLOG_SERVICE SHIPLOG_AUTO_PUSH
}

@test "git shiplog show (no args) shows latest entry" {
  run git shiplog show
  [ "$status" -eq 0 ]
  [[ "$output" == *"SHIPLOG Entry"* ]]
  [[ "$output" == *"Deploy:"* ]]
}
