#!/usr/bin/env bats

load helpers/common

setup() {
  export SHIPLOG_USE_LOCAL_SANDBOX=1
  shiplog_install_cli
  shiplog_use_sandbox_repo
  git config user.name "Shiplog Tester"
  git config user.email "shiplog-tester@example.com"
  shiplog_setup_test_signing
}

teardown() {
  shiplog_cleanup_sandbox_repo
}

@test "setup strict bootstraps trust and sets require_signed (single)" {
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
  export SHIPLOG_TRUST_SIGN=0
  export SHIPLOG_SETUP_STRICT_ENVS="prod"
  export SHIPLOG_SETUP_AUTO_PUSH=0
  export SHIPLOG_BOSUN_BIN=/nonexistent
  export NO_COLOR=1

  run env SHIPLOG_SETUP_STRICTNESS=strict git shiplog setup
  [ "$status" -eq 0 ]
  run jq -r '.require_signed' .shiplog/policy.json
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
  run git rev-parse --verify refs/_shiplog/trust/root
  [ "$status" -eq 0 ]
}
