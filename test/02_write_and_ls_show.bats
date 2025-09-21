#!/usr/bin/env bats

load helpers/common

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}

setup() {
  shiplog_install_cli
  export SHIPLOG_SIGN=0
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

@test "write creates a commit under refs/_shiplog/journal/prod" {
  run bash -lc 'git shiplog --yes write'
  [ "$status" -eq 0 ]
  ref="${REF_ROOT}/journal/prod"
  run git show -s --format=%s "$ref"
  [ "$status" -eq 0 ]
  [[ "$output" == "Deploy: web"* ]]
}

@test "ls shows a formatted table via gum" {
  run git shiplog ls
  [ "$status" -eq 0 ]
  [[ "$output" == *"web"* ]]
  [[ "$output" == *"SUCCESS"* ]]
}

@test "show renders human header and structured trailer" {
  sha=$(git rev-parse "${REF_ROOT}/journal/prod")
  run git shiplog show "$sha"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SHIPLOG Entry"* ]]
  [[ "$output" == *"Structured Trailer"* ]]
  [[ "$output" == *"OPS-0000"* ]]
}
