#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_reset_remote_snapshot_state >/dev/null 2>&1 || true
  shiplog_git_caller remote remove "shimtest-${BATS_TEST_NUMBER}" >/dev/null 2>&1 || true
}

teardown() {
  shiplog_git_caller remote remove "shimtest-${BATS_TEST_NUMBER}" >/dev/null 2>&1 || true
  shiplog_reset_remote_snapshot_state >/dev/null 2>&1 || true
  if [ -n "${_RESTORE_READONLY_TMPDIR:-}" ]; then
    chmod u+w "${_RESTORE_READONLY_TMPDIR}/.git/config" >/dev/null 2>&1 || true
    rm -rf "$_RESTORE_READONLY_TMPDIR"
  fi
}

@test "restore removes unexpected remotes" {
  local remote="shimtest-${BATS_TEST_NUMBER}"
  shiplog_snapshot_caller_repo_state
  git remote add "$remote" https://example.invalid/original.git
  run git remote
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "^$remote$"

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  run git remote
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q "^$remote$"
}

@test "restore rebuilds multi-url remote configuration" {
  local remote="shimtest-${BATS_TEST_NUMBER}"
  git remote add "$remote" https://example.invalid/primary.git
  git remote set-url --add "$remote" ssh://example.invalid/secondary.git
  git remote set-url --push "$remote" ssh://push.invalid/primary.git
  git remote set-url --push --add "$remote" ssh://push.invalid/secondary.git
  git config --add "remote.${remote}.fetch" "+refs/heads/*:refs/remotes/${remote}/*"
  git config --add "remote.${remote}.mirror" true

  local before
  before="$(git config --get-regexp "^remote\.${remote}\." | sort)"

  shiplog_snapshot_caller_repo_state

  git remote remove "$remote"
  git remote add "$remote" https://example.invalid/nope.git
  git config --add "remote.${remote}.fetch" "+refs/tags/*:refs/tags/*"

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after
  after="$(git config --get-regexp "^remote\.${remote}\." | sort)"
  [ "$before" = "$after" ]
}

@test "restore skips with warning when .git/config is read-only" {
  local remote="shimtest-${BATS_TEST_NUMBER}"
  local temp_repo
  temp_repo="$(mktemp -d)"
  _RESTORE_READONLY_TMPDIR="$temp_repo"
  (
    cd "$temp_repo"
    git init -q
    git remote add origin https://example.invalid/readonly.git
    export SHIPLOG_TEST_ROOT="$temp_repo"
    # Container runs as root; force helper to exercise read-only skip path.
    export SHIPLOG_FORCE_REMOTE_RESTORE_SKIP=1
    shiplog_snapshot_caller_repo_state
    git remote remove origin
    chmod u-w .git/config
    run shiplog_restore_caller_remotes
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Skipping remote restore: config is read-only"
    run git remote
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  )
}
