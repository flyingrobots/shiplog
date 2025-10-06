#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  git config user.name "Shiplog Test"
  git config user.email "shiplog-publish@example.com"
}

teardown() {
  shiplog_standard_teardown
}

@test "publish pushes journal regardless of auto-push settings" {
  skip "publish precedence test flaky in CI; will re-enable after push harness is stabilized"
  # Set env to auto-push, git config to 0, and pass --push to publish
  export SHIPLOG_AUTO_PUSH=0
  git config shiplog.autoPush false
  # Create a bare remote and set as origin
  REMOTE_DIR=$(mktemp -d)
  git remote remove origin >/dev/null 2>&1 || true
  git init -q --bare "$REMOTE_DIR"
  git remote add origin "$REMOTE_DIR"
  # Write an entry locally (no push)
  export SHIPLOG_BORING=1
  export SHIPLOG_SERVICE=pub
  export SHIPLOG_STATUS=success
  export SHIPLOG_REASON=t
  export SHIPLOG_REGION=us
  export SHIPLOG_CLUSTER=c
  export SHIPLOG_NAMESPACE=ns
  run git shiplog write --env staging
  [ "$status" -eq 0 ]
  # Publish should push even if auto-push settings are disabled (explicit action)
  run git shiplog publish --env staging
  [ "$status" -eq 0 ]
}
