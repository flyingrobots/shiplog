#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_install_cli
  export SHIPLOG_SIGN=0
  export SHIPLOG_ENV="prod"
}

@test "--boring write consumes SHIPLOG_* defaults" {
  export SHIPLOG_SERVICE="boring-web"
  export SHIPLOG_STATUS="success"
  export SHIPLOG_REASON="non-interactive deploy"
  export SHIPLOG_TICKET="BORING-1"
  export SHIPLOG_REGION="us-east-1"
  export SHIPLOG_CLUSTER="prod-a"
  export SHIPLOG_NAMESPACE="default"
  export SHIPLOG_IMAGE="ghcr.io/example/boring"
  export SHIPLOG_TAG="v1.2.3"
  
  # Cleanup function
  cleanup() {
    unset SHIPLOG_SERVICE SHIPLOG_STATUS SHIPLOG_REASON SHIPLOG_TICKET
    unset SHIPLOG_REGION SHIPLOG_CLUSTER SHIPLOG_NAMESPACE SHIPLOG_IMAGE SHIPLOG_TAG
  }
  trap cleanup EXIT
  run git shiplog --boring write
  [ "$status" -eq 0 ]
  [[ -n "$output" ]] || fail "git shiplog command produced no output"

  run git show -s --format=%s refs/_shiplog/journal/prod
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^"Deploy: boring-web"$ ]] || fail "Expected exact commit message 'Deploy: boring-web', got: '$output'"

  # Verify the journal entry contains expected fields
  run git show refs/_shiplog/journal/prod
  [ "$status" -eq 0 ]

  command -v jq >/dev/null 2>&1 || skip "jq required for JSON assertions"
  local json
  json=$(printf '%s\n' "$output" | awk '/^---/{flag=1;next}flag')
  [ -n "$json" ] || fail "Structured trailer missing from journal entry"

  local field
  field=$(printf '%s\n' "$json" | jq -er '.what.service')
  [ "$field" = "$SHIPLOG_SERVICE" ] || fail "Expected service $SHIPLOG_SERVICE, got $field"

  field=$(printf '%s\n' "$json" | jq -er '.status')
  [ "$field" = "$SHIPLOG_STATUS" ] || fail "Expected status $SHIPLOG_STATUS, got $field"

  field=$(printf '%s\n' "$json" | jq -er '.why.reason')
  [ "$field" = "$SHIPLOG_REASON" ] || fail "Expected reason $SHIPLOG_REASON, got $field"

  field=$(printf '%s\n' "$json" | jq -er '.why.ticket')
  [ "$field" = "$SHIPLOG_TICKET" ] || fail "Expected ticket $SHIPLOG_TICKET, got $field"

  field=$(printf '%s\n' "$json" | jq -er '.where.region')
  [ "$field" = "$SHIPLOG_REGION" ] || fail "Expected region $SHIPLOG_REGION, got $field"

  field=$(printf '%s\n' "$json" | jq -er '.where.cluster')
  [ "$field" = "$SHIPLOG_CLUSTER" ] || fail "Expected cluster $SHIPLOG_CLUSTER, got $field"

  field=$(printf '%s\n' "$json" | jq -er '.where.namespace')
  [ "$field" = "$SHIPLOG_NAMESPACE" ] || fail "Expected namespace $SHIPLOG_NAMESPACE, got $field"

  field=$(printf '%s\n' "$json" | jq -er '.what.artifact')
  [ "$field" = "$SHIPLOG_IMAGE:$SHIPLOG_TAG" ] || fail "Expected artifact $SHIPLOG_IMAGE:$SHIPLOG_TAG, got $field"
}
