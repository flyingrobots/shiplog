#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_install_cli
  command -v jq >/dev/null || skip "jq not present"
}

@test "export-json emits compact NDJSON with commit field" {
  run git shiplog export-json
  [ "$status" -eq 0 ]
  echo "$output" | jq -c . >/dev/null
  first=$(echo "$output" | head -n1)
  echo "$first" | jq -e 'has("commit") and (.status != null)' >/dev/null
}
