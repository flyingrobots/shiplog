#!/usr/bin/env bats

setup() {
  install -m 0755 /workspace/shiplog-lite.sh /usr/local/bin/shiplog
  command -v jq >/dev/null || skip "jq not present"
}

@test "export-json emits compact NDJSON with commit field" {
  run shiplog export-json
  [ "$status" -eq 0 ]
  echo "$output" | jq -c . >/dev/null
  first=$(echo "$output" | head -n1)
  echo "$first" | jq -e 'has("commit") and (.status != null)' >/dev/null
}
