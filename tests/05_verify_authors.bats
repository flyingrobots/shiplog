#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_install_cli
  export SHIPLOG_SIGN=0
  export SHIPLOG_SERVICE="svc"
  run bash -lc 'yes | shiplog write'
  [ "$status" -eq 0 ]
}

@test "write rejects author outside allowlist" {
  export SHIPLOG_AUTHORS="deploy@example.com"
  run bash -lc 'yes | shiplog write'
  [ "$status" -ne 0 ]
  [[ "$output" == *"not in allowlist"* ]]
  unset SHIPLOG_AUTHORS
}

@test "verify passes when no allowlist set" {
  run shiplog verify
  [ "$status" -eq 0 ]
}

@test "verify fails for disallowed author" {
  export SHIPLOG_AUTHORS="allowed@co"
  run shiplog verify
  [ "$status" -ne 0 ]
  [[ "$output" == *"unauthorized author"* ]]
}
