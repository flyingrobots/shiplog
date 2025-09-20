#!/usr/bin/env bats

setup() {
  install -m 0755 /workspace/shiplog-lite.sh /usr/local/bin/shiplog
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
