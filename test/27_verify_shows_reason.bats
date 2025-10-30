#!/usr/bin/env bats

load helpers/common

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_AUTO_PUSH=0
}

teardown() {
  shiplog_standard_teardown
  unset SHIPLOG_AUTO_PUSH
}

@test "verify surfaces reason when entries are unsigned" {
  # Write an unsigned entry
  run bash -lc 'SHIPLOG_BORING=1 git shiplog --yes write prod --service demo'
  [ "$status" -eq 0 ]

  # Prepare a readable allowed_signers file so signature verification gate can run
  mkdir -p .shiplog
  printf '# dummy allowed signers (unused for unsigned)\n' > .shiplog/allowed_signers

  # Force signature verification for verify and expect a helpful reason
  run bash -lc 'SHIPLOG_SIGN=1 SHIPLOG_ALLOWED_SIGNERS=.shiplog/allowed_signers git shiplog verify prod 2>&1'
  [ "$status" -eq 0 ]
  [[ "$output" == *"bad or missing signature"* ]]
  [[ "$output" == *"no signature"* ]]
}

