#!/usr/bin/env bats

load helpers/common

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}
NOTES_REF=${SHIPLOG_NOTES_REF:-refs/_shiplog/notes/logs}

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_SIGN=0
  export SHIPLOG_AUTO_PUSH=0
  export SHIPLOG_SERVICE="api"
  export SHIPLOG_REASON="attached log test"
  export SHIPLOG_IMAGE="ghcr.io/example/api"
  export SHIPLOG_TAG="test.2"
  echo '{"ts":"now","level":"info","msg":"hello"}' > /tmp/demo.ndjson
  export SHIPLOG_LOG=/tmp/demo.ndjson
}

teardown() {
  rm -f /tmp/demo.ndjson
  shiplog_standard_teardown
  unset SHIPLOG_SIGN SHIPLOG_AUTO_PUSH SHIPLOG_SERVICE SHIPLOG_REASON SHIPLOG_IMAGE SHIPLOG_TAG SHIPLOG_LOG
}

@test "write attaches note to commit and show displays it" {
  run bash -lc 'git shiplog --yes write'
  [ "$status" -eq 0 ]
  sha=$(git rev-parse "${REF_ROOT}/journal/prod")

  run git notes --ref="${NOTES_REF}" show "$sha"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello"* ]]

  run git shiplog show "$sha"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Attached Log (notes)"* ]]
}
