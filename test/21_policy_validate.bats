#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
}

teardown() {
  shiplog_standard_teardown
}

@test "policy validate succeeds on working policy" {
  # Standard setup writes a minimal working .shiplog/policy.json
  run git shiplog policy validate
  [ "$status" -eq 0 ]
  [[ "$output" == *"Policy OK"* ]]
}

@test "policy validate fails on malformed policy (missing fields)" {
  mkdir -p .shiplog
  cat > .shiplog/policy.json <<'JSON'
{
  "version": 1,
  "authors": {}
}
JSON
  run git shiplog policy validate
  [ "$status" -ne 0 ]
}

@test "policy validate catches bad types and ref prefixes" {
  mkdir -p .shiplog
  cat > .shiplog/policy.json <<'JSON'
{
  "version": 1,
  "require_signed": "yes",
  "authors": {"default_allowlist": []},
  "deployment_requirements": "nope",
  "notes_ref": "heads/notes"
}
JSON
  run git shiplog policy validate
  [ "$status" -ne 0 ]
  # Expect helpful error lines
  [[ "$output" == *"require_signed: boolean required"* || "$error" == *"require_signed: boolean required"* ]]
  [[ "$output" == *"authors.default_allowlist: non-empty array of strings required"* || "$error" == *"authors.default_allowlist: non-empty array of strings required"* ]]
  [[ "$output" == *"deployment_requirements: object required"* || "$error" == *"deployment_requirements: object required"* ]]
  [[ "$output" == *"notes_ref: must start with refs/"* || "$error" == *"notes_ref: must start with refs/"* ]]
}
