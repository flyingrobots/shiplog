#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  shiplog_standard_setup
}

teardown() {
  shiplog_standard_teardown
}

@test "config dry-run prints plan JSON and makes no changes" {
  export SHIPLOG_BORING=1
  run bash -lc 'git shiplog config --interactive'
  [ "$status" -eq 0 ]
  # stdout should be valid JSON with required keys
  echo "$output" | jq -e '.host and .ref_root and .sig_mode and (.threshold|type=="number") and .require_signed and (.autoPush|type=="number")' >/dev/null
  # No policy written, no config set in dry-run
  [ ! -f ./.shiplog/policy.json ]
  run bash -lc 'git config --get shiplog.refRoot || true'
  [ -z "$output" ]
}

@test "config apply writes policy and sets repo config" {
  export SHIPLOG_BORING=1
  run bash -lc 'git shiplog config --interactive --apply'
  [ "$status" -eq 0 ]
  [ -f ./.shiplog/policy.json ]
  run bash -lc 'git config --get shiplog.refRoot'
  [ "$status" -eq 0 ]
  # self-hosted default without origin → refs/_shiplog
  [ "$output" = "refs/_shiplog" ]
}

@test "config explicit --apply --dry-run is invalid" {
  export SHIPLOG_BORING=1
  run bash -lc 'git shiplog config --interactive --apply --dry-run'
  [ "$status" -ne 0 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

@test "answers-file: threshold coerced and ref_root normalized" {
  cat > answers.json <<JSON
{"host":"github.com","ref_root":"heads/_shiplog","threshold":"not-a-number","sig_mode":"attestation","require_signed":"prod-only","autoPush":0}
JSON
  run bash -lc 'git shiplog config --answers-file answers.json'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.threshold == 1 and .ref_root == "refs/heads/_shiplog"' >/dev/null
}
