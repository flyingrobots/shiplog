#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_install_cli
  shiplog_use_sandbox_repo
  git config user.name "Shiplog Tester"
  git config user.email "shiplog-tester@example.com"
}

teardown() {
  shiplog_cleanup_sandbox_repo
}

@test "setup open writes policy and updates ref" {
  run env SHIPLOG_SETUP_STRICTNESS=open git shiplog setup
  [ "$status" -eq 0 ]
  [ -f .shiplog/policy.json ]
  run jq -r '.require_signed' .shiplog/policy.json
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
  run git rev-parse --verify refs/_shiplog/policy/current
  [ "$status" -eq 0 ]
}

@test "policy show --json emits valid JSON" {
  run git shiplog policy show --json
  [ "$status" -eq 0 ]
  run jq -er '.require_signed | type' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "setup balanced writes allowlist" {
  run env SHIPLOG_SETUP_STRICTNESS=balanced SHIPLOG_SETUP_AUTHORS="shiplog-tester@example.com other@example.com" git shiplog setup
  [ "$status" -eq 0 ]
  run jq -r '.authors.default_allowlist | join(" ")' .shiplog/policy.json
  [ "$status" -eq 0 ]
  [[ "$output" == *"shiplog-tester@example.com"* ]]
  [[ "$output" == *"other@example.com"* ]]
}

@test "setup strict bootstraps trust and sets require_signed" {
  # Create a fake SSH public key file
  mkdir -p tmp
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITESTKEY shiplog@test" > tmp/testkey.pub
  export SHIPLOG_TRUST_COUNT=1
  export SHIPLOG_TRUST_ID="shiplog-trust-root"
  export SHIPLOG_TRUST_1_NAME="Shiplog Tester"
  export SHIPLOG_TRUST_1_EMAIL="shiplog-tester@example.com"
  export SHIPLOG_TRUST_1_ROLE="root"
  export SHIPLOG_TRUST_1_PGP_FPR=""
  export SHIPLOG_TRUST_1_SSH_KEY_PATH="$(pwd)/tmp/testkey.pub"
  export SHIPLOG_TRUST_1_PRINCIPAL="shiplog-tester@example.com"
  export SHIPLOG_TRUST_1_REVOKED="no"
  export SHIPLOG_TRUST_THRESHOLD=1
  export SHIPLOG_TRUST_COMMIT_MESSAGE="shiplog: trust root v1 (GENESIS)"
  export SHIPLOG_ASSUME_YES=1
  export SHIPLOG_PLAIN=1

  run env SHIPLOG_SETUP_STRICTNESS=strict git shiplog setup
  [ "$status" -eq 0 ]
  run jq -r '.require_signed' .shiplog/policy.json
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
  run git rev-parse --verify refs/_shiplog/trust/root
  [ "$status" -eq 0 ]
}

