#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_install_cli
  git remote remove origin >/dev/null 2>&1 || true
  git config user.name "Shiplog Test"
  git config user.email "shiplog-test@example.local"
}

teardown() {
  unset SHIPLOG_SIGN SHIPLOG_ENV SHIPLOG_SERVICE SHIPLOG_STATUS SHIPLOG_REASON
  unset SHIPLOG_REGION SHIPLOG_CLUSTER SHIPLOG_NAMESPACE SHIPLOG_IMAGE SHIPLOG_TAG
  unset SHIPLOG_AUTO_PUSH SHIPLOG_BORING
}

@test "signed commits verify when ENABLE_SIGNING=true image is used" {
  if [ "${ENABLE_SIGNING:-false}" != "true" ]; then
    skip "Built without signing support; set ENABLE_SIGNING=true for this test"
  fi
  export SHIPLOG_SIGN=1
  export SHIPLOG_ENV="signed"
  export SHIPLOG_SERVICE="signed-web"
  export SHIPLOG_STATUS="success"
  export SHIPLOG_REASON="signed deploy"
  export SHIPLOG_REGION="us-west-2"
  export SHIPLOG_CLUSTER="signed-cluster"
  export SHIPLOG_NAMESPACE="default"
  export SHIPLOG_IMAGE="ghcr.io/example/signed"
  export SHIPLOG_TAG="v1.0.0"
  export SHIPLOG_AUTO_PUSH=0
  export SHIPLOG_BORING=1
  run bash -lc 'git shiplog --yes write'
  if [ "$status" -ne 0 ]; then
    echo "signed write output: $output" >&2
  fi
  [ "$status" -eq 0 ]
  run git shiplog verify
  [ "$status" -eq 0 ]
}
