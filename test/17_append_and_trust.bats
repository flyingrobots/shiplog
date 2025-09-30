#!/usr/bin/env bats

load helpers/common

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}
TRUST_REF=${SHIPLOG_TRUST_REF:-refs/_shiplog/trust/root}

reset_shiplog_env() {
  unset SHIPLOG_SERVICE SHIPLOG_STATUS SHIPLOG_REASON SHIPLOG_TICKET
  unset SHIPLOG_REGION SHIPLOG_CLUSTER SHIPLOG_NAMESPACE
  unset SHIPLOG_IMAGE SHIPLOG_TAG SHIPLOG_RUN_URL
  unset SHIPLOG_LOG SHIPLOG_EXTRA_JSON SHIPLOG_BORING SHIPLOG_ASSUME_YES
  export SHIPLOG_ENV=prod
}

setup() {
  reset_shiplog_env
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_SIGN=0
  export SHIPLOG_AUTO_PUSH=0
}

teardown() {
  shiplog_standard_teardown
  unset SHIPLOG_SIGN SHIPLOG_AUTO_PUSH
  reset_shiplog_env
}

@test "write defaults namespace to environment when unset" {
  run bash -c 'SHIPLOG_BORING=1 SHIPLOG_ASSUME_YES=1 SHIPLOG_SERVICE=api git shiplog write staging'
  [ "$status" -eq 0 ]

  run bash -c "git shiplog show --json ${REF_ROOT}/journal/staging | jq -r '.where.namespace'"
  [ "$status" -eq 0 ]
  [ "$output" = "staging" ]
}

@test "append merges provided JSON payload" {
  run bash -c 'git shiplog append --service api --status success --reason "auto" --json '\''{"build":"200"}'\'''
  [ "$status" -eq 0 ]

  run bash -c "git shiplog show --json ${REF_ROOT}/journal/prod"
  [ "$status" -eq 0 ]
  build=$(printf '%s\n' "$output" | jq -r '.build')
  [ "$build" = "200" ]
}

@test "append accepts JSON from stdin" {
  before=$(git rev-parse "${REF_ROOT}/journal/prod" 2>/dev/null || echo "")
  # CI creates a fresh sandbox repo each time, so prod journal should be empty before this append.
  run bash -c 'printf '\''{"build":"201","method":"stdin"}'\'' | git shiplog append --service api --status success --reason "stdin" --json -'
  [ "$status" -eq 0 ]

  after=$(git rev-parse "${REF_ROOT}/journal/prod" 2>/dev/null || echo "")
  [ "$before" != "$after" ]

  run bash -c "git shiplog show --json ${REF_ROOT}/journal/prod"
  [ "$status" -eq 0 ]
  method=$(printf '%s\n' "$output" | jq -r '.method')
  [ "$method" = "stdin" ]
}

@test "trust show prints roster and supports --json" {
  run bash -c 'git show refs/_shiplog/trust/root:trust.json'
  [ "$status" -eq 0 ]

  run bash -c 'git shiplog trust show --json'
  [ "$status" -eq 0 ]
  threshold=$(printf '%s\n' "$output" | jq -r '.threshold')
  [ "$threshold" = "1" ]

  run bash -lc 'git shiplog trust show'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Trust ID"* ]]
  [[ "$output" == *"Allowed signers: "* ]]
  [[ "$output" == *"shiplog-tester@example.com"* ]]
}
