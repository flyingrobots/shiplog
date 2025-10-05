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
  # Record pre-state
  local before_sha=""
  if [ -f ./.shiplog/policy.json ]; then
    before_sha=$(git hash-object ./.shiplog/policy.json)
  fi
  run bash -lc 'git shiplog config --interactive'
  [ "$status" -eq 0 ]
  # stdout should be valid JSON with required keys
  echo "$output" | jq -e '.host and .ref_root and .sig_mode and (.threshold|type=="number") and .require_signed and (.autoPush|type=="number")' >/dev/null
  # No config set in dry-run
  run bash -lc 'git config --get shiplog.refRoot || true'
  [ -z "$output" ]
  # Policy file unchanged if it already existed
  if [ -n "$before_sha" ]; then
    run bash -lc 'git hash-object ./.shiplog/policy.json'
    [ "$output" = "$before_sha" ]
  fi
}

@test "config apply writes policy and sets repo config" {
  export SHIPLOG_BORING=1
  run bash -lc 'SHIPLOG_CONFIG_HOST=self-hosted git shiplog config --interactive --apply'
  [ "$status" -eq 0 ]
  [ -f ./.shiplog/policy.json ]
  run bash -lc 'git config --get shiplog.refRoot'
  [ "$status" -eq 0 ]
  # self-hosted default without origin → refs/_shiplog (allow minor whitespace)
  [[ "$output" == *"refs/_shiplog"* ]]
}

@test "config apply with dry-run does not mutate state (env-forced path)" {
  export SHIPLOG_BORING=1
  # Clear refRoot
  git config --unset-all shiplog.refRoot >/dev/null 2>&1 || true
  # Force env dry-run and ensure no mutation
  run bash -lc 'SHIPLOG_DRY_RUN=1 git shiplog config --interactive --apply'
  [ "$status" -eq 0 ]
  run bash -lc 'git config --get shiplog.refRoot || true'
  # No value set because apply is suppressed by dry-run
  [ -z "$output" ]
}

@test "config explicit --apply --dry-run is invalid" {
  export SHIPLOG_BORING=1
  run bash -lc 'git shiplog config --interactive --apply --dry-run'
  [ "$status" -ne 0 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

@test "answers-file: threshold coerced and ref_root normalized" {
  export SHIPLOG_BORING=1
  git config --unset-all shiplog.refRoot >/dev/null 2>&1 || true
  cat > answers.json <<JSON
{"host":"github.com","ref_root":"heads/_shiplog","threshold":"not-a-number","sig_mode":"attestation","require_signed":"prod-only","autoPush":0}
JSON
  run bash -lc 'git shiplog config --answers-file answers.json --apply'
  [ "$status" -eq 0 ]
  run bash -lc 'git config --get shiplog.refRoot'
  [ "$status" -eq 0 ]
  [[ "$output" == "refs/heads/_shiplog" ]]
}
