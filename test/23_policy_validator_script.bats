#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
}

teardown() {
  shiplog_standard_teardown
}

TEST_VALIDATOR="$SHIPLOG_HOME/scripts/policy/validate.sh"

@test "policy validator script passes valid policy file" {
  [ -x "$TEST_VALIDATOR" ] || skip "validator script missing"
  run "$TEST_VALIDATOR" .shiplog/policy.json
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "policy validator script fails invalid policy" {
  [ -x "$TEST_VALIDATOR" ] || skip "validator script missing"
  cat > .shiplog/policy.json <<'JSON'
{
  "version": 1,
  "require_signed": "maybe"
}
JSON
  run "$TEST_VALIDATOR" .shiplog/policy.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"version: semver"* ]]
  [[ "$output" == *"require_signed"* ]]
}

@test "policy validator script handles stdin" {
  [ -x "$TEST_VALIDATOR" ] || skip "validator script missing"
  run env TEST_VALIDATOR="$TEST_VALIDATOR" bash -c 'printf "{\"version\":\"1.0.0\"}" | "$TEST_VALIDATOR" --stdin'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "cli policy validate uses shared validator" {
  [ -x "$TEST_VALIDATOR" ] || skip "validator script missing"
  run git shiplog policy validate
  [ "$status" -eq 0 ]
  cat > .shiplog/policy.json <<'JSON'
{
  "version": "bogus",
  "require_signed": false
}
JSON
  run git shiplog policy validate
  [ "$status" -ne 0 ]
  [[ "$output" == *"version"* ]]
}
