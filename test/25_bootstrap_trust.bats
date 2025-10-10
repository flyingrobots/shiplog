#!/usr/bin/env bats

load helpers/common

setup() {
  TMP_NON_REPO=$(mktemp -d)
}

teardown() {
  rm -rf "$TMP_NON_REPO"
}

@test "shiplog-bootstrap-trust hints when run outside git repo" {
  run bash -c "cd '$TMP_NON_REPO' && SHIPLOG_PLAIN=1 SHIPLOG_ASSUME_YES=1 '$SHIPLOG_PROJECT_ROOT/scripts/shiplog-bootstrap-trust.sh' --no-push"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not inside a git repository"* ]]
  [[ "$output" == *"$TMP_NON_REPO"* ]]
}
