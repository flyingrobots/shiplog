#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_install_cli
  git config user.name "Shiplog Test"
  git config user.email "shiplog-policy@example.com"
  git commit --allow-empty -m init >/dev/null
  mkdir -p .shiplog
}

@test "policy show reports file source" {
  cat <<POLICY > .shiplog/policy.json
{
  "version": 1,
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
  "version": 1,
  "require_signed": false,
  "authors": {
    "default_allowlist": [
      "shiplog-policy@example.com"
    ]
  }
}
POLICY
  run bash -lc 'git shiplog --yes write'
  [ "$status" -eq 0 ]
}
