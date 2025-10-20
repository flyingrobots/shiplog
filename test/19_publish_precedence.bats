#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  shiplog_use_temp_remote origin REMOTE_DIR
}

teardown() {
  shiplog_standard_teardown
}

@test "publish pushes journal regardless of auto-push settings" {
  # Disable auto-push via env and git config
  export SHIPLOG_AUTO_PUSH=0
  git config shiplog.autoPush false

  # Remote already configured in setup

  # Create a journal entry locally (default user/email is allowed by policy)
  export SHIPLOG_BORING=1
  export SHIPLOG_SERVICE=pub
  export SHIPLOG_STATUS=success
  export SHIPLOG_REASON=t
  export SHIPLOG_REGION=us
  export SHIPLOG_CLUSTER=c
  export SHIPLOG_NAMESPACE=stg
  run git shiplog write --env staging
  [ "$status" -eq 0 ]

  # Publish should push the journal even when auto-push is disabled
  run git shiplog publish --env staging
  [ "$status" -eq 0 ]

  # Verify the remote now has the journal ref
  run git --git-dir="$REMOTE_DIR" for-each-ref 'refs/_shiplog/journal/staging' --format='%(refname)'
  [ "$status" -eq 0 ]
  [[ "$output" == *"refs/_shiplog/journal/staging"* ]]

  git --git-dir="$REMOTE_DIR" update-ref -d refs/_shiplog/journal/staging >/dev/null 2>&1 || true
  git update-ref -d refs/_shiplog/journal/staging >/dev/null 2>&1 || true
}
