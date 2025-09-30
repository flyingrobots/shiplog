#!/usr/bin/env bats

load helpers/common

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}
TRUST_REF=${SHIPLOG_TRUST_REF:-refs/_shiplog/trust/root}

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_SIGN=0
  export SHIPLOG_AUTO_PUSH=0
}

teardown() {
  shiplog_standard_teardown
  unset SHIPLOG_SIGN SHIPLOG_AUTO_PUSH
}

@test "write defaults namespace to environment when unset" {
  run bash -lc 'SHIPLOG_BORING=1 SHIPLOG_ASSUME_YES=1 SHIPLOG_SERVICE=api git shiplog write staging'
  [ "$status" -eq 0 ]

  run bash -lc "git shiplog show --json ${REF_ROOT}/journal/staging | jq -r '.where.namespace'"
  [ "$status" -eq 0 ]
  [ "$output" = "staging" ]
}

@test "append merges provided JSON payload" {
  run bash -lc 'git shiplog append --service api --status success --reason "auto" --json '\''{"build":"200"}'\'''
  [ "$status" -eq 0 ]

  run bash -lc "git shiplog show --json ${REF_ROOT}/journal/prod | jq -r '.build'"
  [ "$status" -eq 0 ]
  [ "$output" = "200" ]
}

@test "trust show prints roster and supports --json" {
  run bash -lc 'git show refs/_shiplog/trust/root:trust.json'
  [ "$status" -eq 0 ]

  run bash -lc 'git shiplog trust show --json'
  [ "$status" -eq 0 ]
  threshold=$(printf '%s\n' "$output" | jq -r '.threshold')
  [ "$threshold" = "1" ]

  run bash -lc 'git shiplog trust show'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Trust ID"* ]]
}
