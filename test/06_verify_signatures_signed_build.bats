#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_install_cli || {
    echo "Failed to install shiplog CLI" >&2
    return 1
  }
  git remote remove origin >/dev/null 2>&1 || true
  git config user.name "Shiplog Test"
  git config user.email "shiplog-test@example.local"
}

teardown() {
  unset SHIPLOG_SIGN SHIPLOG_ENV SHIPLOG_SERVICE SHIPLOG_STATUS SHIPLOG_REASON
  unset SHIPLOG_REGION SHIPLOG_CLUSTER SHIPLOG_NAMESPACE SHIPLOG_IMAGE SHIPLOG_TAG
  unset SHIPLOG_AUTO_PUSH SHIPLOG_BORING
}

@test "signed commits verify when signing support is enabled" {
  if [ "${ENABLE_SIGNING:-false}" != "true" ]; then
    skip "Built without signing support; set ENABLE_SIGNING=true for this test"
  fi
  skip "Signing workflow pending reliable GPG setup in CI"
}
