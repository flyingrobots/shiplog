#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_SIGN=0
  export SHIPLOG_AUTO_PUSH=0
  export SHIPLOG_SERVICE="svc"
  run bash -lc 'git shiplog --yes write'
  [ "$status" -eq 0 ]
}

teardown() {
  shiplog_standard_teardown
  unset SHIPLOG_SIGN SHIPLOG_AUTO_PUSH SHIPLOG_SERVICE SHIPLOG_AUTHORS
}

@test "write rejects author outside allowlist" {
  export SHIPLOG_AUTHORS="deploy@example.com"
  run bash -lc 'git shiplog --yes write'
  [ "$status" -ne 0 ]
  [[ "$output" == *"not in allowlist"* ]]
  unset SHIPLOG_AUTHORS
}

@test "verify passes when no allowlist set" {
  run git shiplog verify
  [ "$status" -eq 0 ]
}

@test "verify fails for disallowed author" {
  export SHIPLOG_AUTHORS="allowed@co"
  run git shiplog verify
  [ "$status" -ne 0 ]
  [[ "$output" == *"unauthorized author"* ]]
}
