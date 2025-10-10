#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
  TEST_VALIDATOR="$SHIPLOG_PROJECT_ROOT/scripts/policy/validate.sh"
}

teardown() {
  shiplog_standard_teardown
}

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
  run "$TEST_VALIDATOR" .shiplog/policy.json
  script_status="$status"
  [ "$script_status" -ne 0 ]
  run env SHIPLOG_BORING=1 git shiplog policy validate
  [ "$status" -eq "$script_status" ]
}

@test "policy validator script reports jq parser failures" {
  [ -x "$TEST_VALIDATOR" ] || skip "validator script missing"
  run env TEST_VALIDATOR="$TEST_VALIDATOR" bash -c 'printf "{" | "$TEST_VALIDATOR" --stdin'
  [ "$status" -ne 0 ]
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"parse error"* || "$output" == *"error"* ]]
}

@test "policy validator script ignores unsafe override paths" {
  [ -x "$TEST_VALIDATOR" ] || skip "validator script missing"
  tmp_override="$BATS_TEST_TMPDIR/evil.jq"
  printf '"bad filter"' > "$tmp_override"
  chmod 666 "$tmp_override"
  run env SHIPLOG_POLICY_VALIDATOR="$tmp_override" "$TEST_VALIDATOR" .shiplog/policy.json
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
