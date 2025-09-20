#!/usr/bin/env bats

setup() {
  install -m 0755 /workspace/shiplog-lite.sh /usr/local/bin/shiplog
}

@test "signed commits verify when ENABLE_SIGNING=true image is used" {
  if [ "${ENABLE_SIGNING:-false}" != "true" ]; then
    skip "Built without signing support; set ENABLE_SIGNING=true for this test"
  fi
  export SHIPLOG_SIGN=1
  export SHIPLOG_ENV="signed"
  export SHIPLOG_SERVICE="signed-web"
  run bash -lc 'yes | shiplog write'
  [ "$status" -eq 0 ]
  run shiplog verify
  [ "$status" -eq 0 ]
}
