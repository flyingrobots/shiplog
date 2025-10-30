#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
}

teardown() {
  shiplog_standard_teardown
}

@test "trust-sign surfaces ssh-keygen failure reason" {
  # Create a commit containing trust.json so the script can build a payload
  printf '{"id":"test-root","threshold":1}\n' > trust.json
  git add trust.json
  git commit -m "add trust.json" >/dev/null
  sha=$(git rev-parse HEAD)

  # Configure an invalid signing key (empty file) to trigger ssh-keygen error
  touch badkey
  chmod 600 badkey
  git config user.signingkey "$(pwd)/badkey"

  run bash -lc "${SHIPLOG_PROJECT_ROOT}/scripts/shiplog-trust-sign.sh ${sha} 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ssh-keygen failed to sign payload"* ]]
}

