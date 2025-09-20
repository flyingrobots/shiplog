#!/usr/bin/env bats

load helpers/common

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}
NOTES_REF=${SHIPLOG_NOTES_REF:-refs/_shiplog/notes/logs}

setup() {
  shiplog_install_cli
  export SHIPLOG_SIGN=0
  export SHIPLOG_SERVICE="api"
  export SHIPLOG_REASON="attached log test"
  export SHIPLOG_IMAGE="ghcr.io/example/api"
  export SHIPLOG_TAG="test.2"
  echo '{"ts":"now","level":"info","msg":"hello"}' > /tmp/demo.ndjson
  export SHIPLOG_LOG=/tmp/demo.ndjson
}

@test "write attaches note to commit and show displays it" {
  run bash -lc 'yes | shiplog write'
  [ "$status" -eq 0 ]
  sha=$(git rev-parse "${REF_ROOT}/journal/prod")

  run git notes --ref="${NOTES_REF}" show "$sha"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello"* ]]

  run shiplog show "$sha"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Attached Log (notes)"* ]]
}
