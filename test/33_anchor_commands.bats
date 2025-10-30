#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_AUTO_PUSH=0
}

teardown() {
  shiplog_standard_teardown
  unset SHIPLOG_AUTO_PUSH
}

@test "anchor set/show/list" {
  run bash -lc '
    git shiplog run --service test -- bash -lc "printf hi" >/dev/null
    git shiplog anchor set --env prod --reason "start deploy"
    git shiplog anchor show --env prod
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"anchor set"* ]]
  [[ "$output" == *"⚓️"* ]]

  run bash -lc 'git shiplog anchor list --env prod'
  [ "$status" -eq 0 ]
}

@test "replay --since-anchor uses anchor boundary" {
  run bash -lc '
    git shiplog anchor set --env prod --reason before >/dev/null
    git shiplog run --service test -- bash -lc "printf AFTER"
    git shiplog replay --env prod --since-anchor --count 50 --speed 0
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"AFTER"* ]]
}

