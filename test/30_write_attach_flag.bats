#!/usr/bin/env bats

load helpers/common

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}
NOTES_REF=${SHIPLOG_NOTES_REF:-refs/_shiplog/notes/logs}

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_SIGN=0
  export SHIPLOG_AUTO_PUSH=0
}

teardown() {
  shiplog_standard_teardown
  unset SHIPLOG_SIGN SHIPLOG_AUTO_PUSH
}

@test "write --log PATH attaches note" {
  tmp_log="${BATS_TMPDIR}/shiplog-write-log-${BATS_TEST_NUMBER:-0}-$RANDOM$RANDOM.ndjson"
  echo '{"msg":"from --log"}' > "$tmp_log"

  run bash -lc 'git shiplog --yes write --service api --status success --reason "log flag" --log '"$tmp_log"  
  [ "$status" -eq 0 ]

  sha=$(git rev-parse "${REF_ROOT}/journal/prod")
  run git notes --ref="${NOTES_REF}" show "$sha"
  [ "$status" -eq 0 ]
  [[ "$output" == *"from --log"* ]]

  # write-only entries do not include a .run block
  run bash -lc "git shiplog show --json $sha | jq -e 'has(\"run\") | not'"
  [ "$status" -eq 0 ]

  rm -f "$tmp_log"
}

@test "write --attach PATH attaches note (alias)" {
  tmp_log="${BATS_TMPDIR}/shiplog-write-attach-${BATS_TEST_NUMBER:-0}-$RANDOM$RANDOM.ndjson"
  echo '{"msg":"from --attach"}' > "$tmp_log"

  run bash -lc 'git shiplog --yes write --service api --status success --reason "attach flag" --attach '"$tmp_log"  
  [ "$status" -eq 0 ]

  sha=$(git rev-parse "${REF_ROOT}/journal/prod")
  run git notes --ref="${NOTES_REF}" show "$sha"
  [ "$status" -eq 0 ]
  [[ "$output" == *"from --attach"* ]]

  # write-only entries do not include a .run block
  run bash -lc "git shiplog show --json $sha | jq -e 'has(\"run\") | not'"
  [ "$status" -eq 0 ]

  rm -f "$tmp_log"
}

@test "write without --log/--attach creates no note" {
  run bash -lc 'git shiplog --yes write --service api --status success --reason "no note"'
  [ "$status" -eq 0 ]
  sha=$(git rev-parse "${REF_ROOT}/journal/prod")
  run git notes --ref="${NOTES_REF}" show "$sha"
  [ "$status" -ne 0 ]
  # write-only entries do not include a .run block
  run bash -lc "git shiplog show --json $sha | jq -e 'has(\"run\") | not'"
  [ "$status" -eq 0 ]
  # human output should not include an Attached Log section
  run bash -lc "git shiplog show $sha"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Attached Log (notes)"* ]]
}
