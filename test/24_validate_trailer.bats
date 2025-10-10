#!/usr/bin/env bats

load helpers/common

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_AUTO_PUSH=0
  export SHIPLOG_SIGN=0
  export SHIPLOG_SERVICE="validate-trailer"
  export SHIPLOG_STATUS="success"
  export SHIPLOG_REASON="validate trailer tests"
}

teardown() {
  unset SHIPLOG_AUTO_PUSH SHIPLOG_SIGN SHIPLOG_SERVICE SHIPLOG_STATUS SHIPLOG_REASON
  shiplog_standard_teardown
}

latest_journal_ref() {
  printf '%s/journal/prod' "$REF_ROOT"
}

write_valid_entry() {
  run git shiplog --yes write
  [ "$status" -eq 0 ]
}

make_commit_with_trailer() {
  local message="$1"
  local ref
  ref=$(latest_journal_ref)
  local parent tree
  parent=$(git rev-parse "$ref")
  tree=$(git rev-parse "${ref}^{tree}")
  local commit
  commit=$(GIT_AUTHOR_NAME="Shiplog Tester" \
           GIT_AUTHOR_EMAIL="shiplog-tester@example.com" \
           GIT_COMMITTER_NAME="Shiplog Tester" \
           GIT_COMMITTER_EMAIL="shiplog-tester@example.com" \
           git commit-tree "$tree" -p "$parent" <<<"$message")
  git update-ref "$ref" "$commit" "$parent"
}

@test "validate-trailer succeeds on latest entry" {
  write_valid_entry
  run git shiplog validate-trailer
  [ "$status" -eq 0 ]
  [[ "$output" == *"Trailer OK"* ]]
}

@test "validate-trailer fails on malformed JSON trailer" {
  write_valid_entry
  make_commit_with_trailer $'shiplog: malformed trailer\n\n---\n{"env": "prod"'
  run git shiplog validate-trailer
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid JSON trailer"* || "$output" == *"parse"* ]]
}

@test "validate-trailer flags missing required fields" {
  write_valid_entry
  make_commit_with_trailer $'shiplog: missing fields\n\n---\n{"env":"prod","ts":"2025-10-10T00:00:00Z","status":"success","what":{},"when":{"dur_s":5}}'
  run git shiplog validate-trailer
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing_or_invalid:what.service"* ]]
}
