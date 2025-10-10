#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  git config user.name "Shiplog Test"
  git config user.email "shiplog-policy@example.com"
  mkdir -p .shiplog
  export SHIPLOG_SIGN=0
  export SHIPLOG_AUTO_PUSH=0
  export SHIPLOG_SERVICE="policy-test"
  export SHIPLOG_STATUS="success"
  export SHIPLOG_REASON="policy"
  export SHIPLOG_REGION="us-west-2"
  export SHIPLOG_CLUSTER="policy"
  export SHIPLOG_NAMESPACE="default"
}

teardown() {
  shiplog_standard_teardown
  unset SHIPLOG_SIGN SHIPLOG_AUTO_PUSH SHIPLOG_SERVICE SHIPLOG_STATUS SHIPLOG_REASON
  unset SHIPLOG_REGION SHIPLOG_CLUSTER SHIPLOG_NAMESPACE
}

@test "policy show reports file source" {
  cat <<POLICY > .shiplog/policy.json
{
  "version": "1.0.0",
  "require_signed": false,
  "authors": {
    "default_allowlist": [
      "shiplog-policy@example.com"
    ]
  }
}
POLICY
  run git shiplog policy --boring show
  [ "$status" -eq 0 ]
  [[ "$output" == *"Source: policy-file:.shiplog/policy.json"* ]]
  [[ "$output" == *"Allowed Authors"* ]]
}

@test "policy allowlist permits write" {
  cat <<POLICY > .shiplog/policy.json
{
  "version": "1.0.0",
  "require_signed": false,
  "authors": {
    "default_allowlist": [
      "shiplog-policy@example.com"
    ]
  }
}
POLICY
  run git shiplog --yes write
  [ "$status" -eq 0 ]
}
