#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_install_cli
  export SHIPLOG_SIGN=0
  export SHIPLOG_ENV="prod"
}

@test "--boring write consumes SHIPLOG_* defaults" {
  # Save original environment
  local original_vars=$(env | grep '^SHIPLOG_' || true)
  
  export SHIPLOG_SERVICE="boring-web"
  export SHIPLOG_STATUS="success"
  export SHIPLOG_REASON="non-interactive deploy"
  export SHIPLOG_TICKET="BORING-1"
  export SHIPLOG_REGION="us-east-1"
  export SHIPLOG_CLUSTER="prod-a"
  export SHIPLOG_NAMESPACE="default"
  export SHIPLOG_IMAGE="ghcr.io/example/boring"
  export SHIPLOG_TAG="v1.2.3"
  
  # Cleanup function
  cleanup() {
    unset SHIPLOG_SERVICE SHIPLOG_STATUS SHIPLOG_REASON SHIPLOG_TICKET
    unset SHIPLOG_REGION SHIPLOG_CLUSTER SHIPLOG_NAMESPACE SHIPLOG_IMAGE SHIPLOG_TAG
  }
  trap cleanup EXIT
  run shiplog --boring write
  [ "$status" -eq 0 ]
  [[ -n "$output" ]] || fail "shiplog command produced no output"

  run git show -s --format=%s refs/_shiplog/journal/prod
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^"Deploy: boring-web"$ ]] || fail "Expected exact commit message 'Deploy: boring-web', got: '$output'"

  # Verify the journal entry contains expected fields
  run git show refs/_shiplog/journal/prod
  [ "$status" -eq 0 ]
  [[ "$output" =~ "boring-web" ]] || fail "Journal entry missing service name"
  [[ "$output" =~ "success" ]] || fail "Journal entry missing status"
}
