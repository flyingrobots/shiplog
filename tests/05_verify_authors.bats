#!/usr/bin/env bats

setup() {
  install -m 0755 /workspace/shiplog-lite.sh /usr/local/bin/shiplog
  export SHIPLOG_SIGN=0
  export SHIPLOG_SERVICE="svc"
  run bash -lc 'yes | shiplog write'
  [ "$status" -eq 0 ]
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
