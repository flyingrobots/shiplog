#!/usr/bin/env bats

load helpers/common

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_SIGN=0
  export SHIPLOG_AUTO_PUSH=0
  export SHIPLOG_SERVICE="web"
  export SHIPLOG_REASON="test hotfix"
  export SHIPLOG_TICKET="OPS-0000"
  export SHIPLOG_REGION="us-west-2"
  export SHIPLOG_CLUSTER="prod-1"
  export SHIPLOG_NAMESPACE="pf3"
  export SHIPLOG_IMAGE="ghcr.io/example/web"
  export SHIPLOG_TAG="test.1"
  export SHIPLOG_RUN_URL="https://ci/run/123"
}

teardown() {
  unset SHIPLOG_SERVICE SHIPLOG_STATUS SHIPLOG_REASON SHIPLOG_TICKET
  unset SHIPLOG_REGION SHIPLOG_CLUSTER SHIPLOG_NAMESPACE SHIPLOG_IMAGE SHIPLOG_TAG
  unset SHIPLOG_AUTO_PUSH SHIPLOG_SIGN
  shiplog_standard_teardown
}

@test "write creates a commit under refs/_shiplog/journal/prod" {
  run git shiplog --yes write
  [ "$status" -eq 0 ]
  ref="${REF_ROOT}/journal/prod"
  run git show -s --format=%s "$ref"
  [ "$status" -eq 0 ]
  [[ "$output" == "Deploy: web"* ]]
}

@test "write --dry-run previews without writing" {
  run git show-ref "${REF_ROOT}/journal/prod"
  [ "$status" -ne 0 ]

  run git shiplog --boring write --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would sign & append entry to ${REF_ROOT}/journal/prod"* ]]

  run git show-ref "${REF_ROOT}/journal/prod"
  [ "$status" -ne 0 ]
}

@test "ls shows a formatted table via bosun" {
  run git shiplog --yes write
  [ "$status" -eq 0 ]
  run git shiplog ls
  [ "$status" -eq 0 ]
  [[ "$output" == *"web"* ]]
  [[ "$output" == *"SUCCESS"* ]]
}

@test "show renders human header and seq" {
  run git shiplog --yes write
  [ "$status" -eq 0 ]
  sha=$(git rev-parse "${REF_ROOT}/journal/prod")
  run git shiplog show "$sha"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SHIPLOG Entry"* ]]
  [[ "$output" == *"Seq:"* ]]
  [[ "$output" == *"OPS-0000"* ]]
}

@test "--boring write consumes SHIPLOG defaults" {
  export SHIPLOG_SERVICE="boring-web"
  export SHIPLOG_STATUS="success"
  export SHIPLOG_REASON="non-interactive deploy"
  export SHIPLOG_TICKET="BORING-1"
  export SHIPLOG_REGION="us-east-1"
  export SHIPLOG_CLUSTER="prod-a"
  export SHIPLOG_NAMESPACE="default"
  export SHIPLOG_IMAGE="ghcr.io/example/boring"
  export SHIPLOG_TAG="v1.2.3"

  run git shiplog --boring write
  if [ "$status" -ne 0 ]; then
    printf 'git shiplog write output:\n%s\n' "$output" >&2
  fi
  [ "$status" -eq 0 ]
  if [ -z "$output" ]; then
    echo "git shiplog command produced no output" >&2
    return 1
  fi

  run git show -s --format=%s "${REF_ROOT}/journal/prod"
  [ "$status" -eq 0 ]
  if [[ ! "$output" =~ ^"Deploy: boring-web" ]]; then
    echo "Expected commit subject to start with service name" >&2
    return 1
  fi

  command -v jq >/dev/null 2>&1 || skip "jq required for JSON assertions"
  local raw json
  raw=$(git cat-file commit "${REF_ROOT}/journal/prod" | sed '1,/^$/d')
  json=$(printf '%s\n' "$raw" | awk '/^[[:space:]]*---/{flag=1;next}flag')
  if [ -z "$json" ]; then
    printf 'Journal output:\n%s\n' "$output" >&2
    echo "Structured trailer missing from journal entry" >&2
    return 1
  fi

  local field
  field=$(printf '%s\n' "$json" | jq -er '.what.service')
  if [ "$field" != "$SHIPLOG_SERVICE" ]; then
    echo "Expected service $SHIPLOG_SERVICE, got $field" >&2
    return 1
  fi

  field=$(printf '%s\n' "$json" | jq -er '.status')
  if [ "$field" != "$SHIPLOG_STATUS" ]; then
    echo "Expected status $SHIPLOG_STATUS, got $field" >&2
    return 1
  fi

  field=$(printf '%s\n' "$json" | jq -er '.why.reason')
  if [ "$field" != "$SHIPLOG_REASON" ]; then
    echo "Expected reason $SHIPLOG_REASON, got $field" >&2
    return 1
  fi

  field=$(printf '%s\n' "$json" | jq -er '.why.ticket')
  if [ "$field" != "$SHIPLOG_TICKET" ]; then
    echo "Expected ticket $SHIPLOG_TICKET, got $field" >&2
    return 1
  fi

  field=$(printf '%s\n' "$json" | jq -er '.where.region')
  if [ "$field" != "$SHIPLOG_REGION" ]; then
    echo "Expected region $SHIPLOG_REGION, got $field" >&2
    return 1
  fi

  field=$(printf '%s\n' "$json" | jq -er '.where.cluster')
  if [ "$field" != "$SHIPLOG_CLUSTER" ]; then
    echo "Expected cluster $SHIPLOG_CLUSTER, got $field" >&2
    return 1
  fi

  field=$(printf '%s\n' "$json" | jq -er '.where.namespace')
  if [ "$field" != "$SHIPLOG_NAMESPACE" ]; then
    echo "Expected namespace $SHIPLOG_NAMESPACE, got $field" >&2
    return 1
  fi

  field=$(printf '%s\n' "$json" | jq -er '.what.artifact')
  if [ "$field" != "$SHIPLOG_IMAGE:$SHIPLOG_TAG" ]; then
    echo "Expected artifact $SHIPLOG_IMAGE:$SHIPLOG_TAG, got $field" >&2
    return 1
  fi
}
