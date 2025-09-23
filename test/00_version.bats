#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
}

teardown() {
  shiplog_standard_teardown
}

@test "bosun --version prints identifier" {
  run "$SHIPLOG_HOME/scripts/bosun" --version
  [ "$status" -eq 0 ]
  [[ "$output" == bosun\ * ]]
}

@test "git shiplog --version prints identifier" {
  run git shiplog --version
  [ "$status" -eq 0 ]
  [[ "$output" == shiplog\ * ]]
}

@test "git shiplog version subcommand prints identifier" {
  run git shiplog version
  [ "$status" -eq 0 ]
  [[ "$output" == shiplog\ * ]]
}
