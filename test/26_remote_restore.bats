#!/usr/bin/env bats

load helpers/common

setup() {
  REMOTE_UNDER_TEST="shimtest-${BATS_TEST_NUMBER}"
  SECONDARY_REMOTE="${REMOTE_UNDER_TEST}-secondary"
  TMP_PRIMARY_REMOTE=""
  TMP_SECONDARY_REMOTE=""
  shiplog_reset_remote_snapshot_state >/dev/null 2>&1 || true
  shiplog_git_caller remote remove "$REMOTE_UNDER_TEST" >/dev/null 2>&1 || true
  shiplog_git_caller remote remove "$SECONDARY_REMOTE" >/dev/null 2>&1 || true
}

teardown() {
  shiplog_git_caller remote remove "$REMOTE_UNDER_TEST" >/dev/null 2>&1 || true
  shiplog_git_caller remote remove "$SECONDARY_REMOTE" >/dev/null 2>&1 || true
  [ -z "$TMP_PRIMARY_REMOTE" ] || rm -rf "$TMP_PRIMARY_REMOTE"
  [ -z "$TMP_SECONDARY_REMOTE" ] || rm -rf "$TMP_SECONDARY_REMOTE"
  shiplog_reset_remote_snapshot_state >/dev/null 2>&1 || true
}

capture_remote_section() {
  local remote="$1"
  shiplog_git_caller config --local --get-regexp "^remote\\.${remote}\\." 2>/dev/null | sort
}

@test "restore removes remotes that were added after snapshot" {
  shiplog_snapshot_caller_repo_state

  TMP_PRIMARY_REMOTE="$(mktemp -d)"
  git init -q --bare "$TMP_PRIMARY_REMOTE"

  shiplog_git_caller remote add "$REMOTE_UNDER_TEST" "$TMP_PRIMARY_REMOTE"
  shiplog_git_caller remote set-url --add "$REMOTE_UNDER_TEST" "https://example.invalid/${REMOTE_UNDER_TEST}.git"
  shiplog_git_caller remote set-url --push "$REMOTE_UNDER_TEST" "ssh://example.invalid/${REMOTE_UNDER_TEST}-push.git"
  shiplog_git_caller config --local --add "remote.${REMOTE_UNDER_TEST}.mirror" true
  shiplog_git_caller config --local --add "remote.${REMOTE_UNDER_TEST}.fetch" "+refs/heads/*:refs/remotes/${REMOTE_UNDER_TEST}/*"
  shiplog_git_caller config --local --add "remote.${REMOTE_UNDER_TEST}.prune" true

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  echo "$output" | grep -qv "^${REMOTE_UNDER_TEST}\$"
}

@test "restore rehydrates complex remote configuration" {
  TMP_PRIMARY_REMOTE="$(mktemp -d)"
  TMP_SECONDARY_REMOTE="$(mktemp -d)"
  git init -q --bare "$TMP_PRIMARY_REMOTE"
  git init -q --bare "$TMP_SECONDARY_REMOTE"

  shiplog_git_caller remote add "$REMOTE_UNDER_TEST" "$TMP_PRIMARY_REMOTE"
  shiplog_git_caller remote set-url --add "$REMOTE_UNDER_TEST" "https://example.invalid/${REMOTE_UNDER_TEST}.git"
  shiplog_git_caller remote set-url --push "$REMOTE_UNDER_TEST" "ssh://example.invalid/${REMOTE_UNDER_TEST}-push.git"
  shiplog_git_caller remote set-url --push --add "$REMOTE_UNDER_TEST" "ssh://example.invalid/${REMOTE_UNDER_TEST}-push-secondary.git"
  shiplog_git_caller config --local --add "remote.${REMOTE_UNDER_TEST}.mirror" true
  shiplog_git_caller config --local --add "remote.${REMOTE_UNDER_TEST}.prune" true
  shiplog_git_caller config --local --add "remote.${REMOTE_UNDER_TEST}.fetch" "+refs/heads/*:refs/remotes/${REMOTE_UNDER_TEST}/*"
  shiplog_git_caller config --local --add "remote.${REMOTE_UNDER_TEST}.fetch" "+refs/tags/*:refs/tags/*"

  local baseline
  baseline="$(capture_remote_section "$REMOTE_UNDER_TEST")"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote remove "$REMOTE_UNDER_TEST"
  shiplog_git_caller remote add "$REMOTE_UNDER_TEST" "$TMP_SECONDARY_REMOTE"
  shiplog_git_caller config --local --add "remote.${REMOTE_UNDER_TEST}.fetch" "+refs/heads/main:refs/tmp/main"

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local restored
  restored="$(capture_remote_section "$REMOTE_UNDER_TEST")"
  [ "$baseline" = "$restored" ]
}
