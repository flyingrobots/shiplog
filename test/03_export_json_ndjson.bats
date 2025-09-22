#!/usr/bin/env bats

load helpers/common

setup() {
  command -v jq >/dev/null || skip "jq not present"
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_SIGN=0
  export SHIPLOG_AUTO_PUSH=0
  export SHIPLOG_SERVICE="exporter"
  export SHIPLOG_STATUS="success"
  export SHIPLOG_REASON="export json"
  export SHIPLOG_TICKET="EXP-1"
  export SHIPLOG_REGION="us-west-2"
  export SHIPLOG_CLUSTER="prod-1"
  export SHIPLOG_NAMESPACE="default"
  export SHIPLOG_IMAGE="ghcr.io/example/export"
  export SHIPLOG_TAG="v0.0.1"
  export SHIPLOG_RUN_URL="https://ci.example.local/run/export"
}

teardown() {
  shiplog_standard_teardown
  unset SHIPLOG_SIGN SHIPLOG_AUTO_PUSH SHIPLOG_SERVICE SHIPLOG_STATUS SHIPLOG_REASON
  unset SHIPLOG_TICKET SHIPLOG_REGION SHIPLOG_CLUSTER SHIPLOG_NAMESPACE
  unset SHIPLOG_IMAGE SHIPLOG_TAG SHIPLOG_RUN_URL
}

@test "export-json emits compact NDJSON with commit field" {
  git shiplog --boring --yes write >/dev/null
  run git shiplog export-json
  [ "$status" -eq 0 ]
  echo "$output" | jq -c . >/dev/null
  first=$(echo "$output" | head -n1)
  echo "$first" | jq -e 'has("commit") and (.status != null)' >/dev/null
}
