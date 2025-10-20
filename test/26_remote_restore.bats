#!/usr/bin/env bats

load helpers/common

REMOTE_RESTORE_SKIPPED=0
ORIG_REMOTE_LIST=""
ORIG_ORIGIN_URLS=""
ORIG_ORIGIN_FETCHES=""
ORIG_ORIGIN_PUSHURLS=""
ORIG_HAVE_ORIGIN=0

setup() {
  shiplog_standard_setup
  ORIG_REMOTE_LIST=$(git remote)
  if git remote | grep -qx origin; then
    ORIG_HAVE_ORIGIN=1
    ORIG_ORIGIN_URLS=$(git config --get-all remote.origin.url 2>/dev/null || printf '')
    ORIG_ORIGIN_FETCHES=$(git config --get-all remote.origin.fetch 2>/dev/null || printf '')
    ORIG_ORIGIN_PUSHURLS=$(git config --get-all remote.origin.pushurl 2>/dev/null || printf '')
  else
    ORIG_HAVE_ORIGIN=0
    ORIG_ORIGIN_URLS=""
    ORIG_ORIGIN_FETCHES=""
    ORIG_ORIGIN_PUSHURLS=""
  fi
}

teardown() {
  if [ "$REMOTE_RESTORE_SKIPPED" -eq 0 ]; then
    shiplog_standard_teardown
  else
    # Ensure global env tracking resets for subsequent files
    REMOTE_RESTORE_SKIPPED=0
  fi
}

@test "sandbox teardown restores caller remote configuration" {
  # Mutate caller remotes directly to simulate an unsafe test
  local stray_remote_dir
  stray_remote_dir=$(mktemp -d)
  git init -q --bare "$stray_remote_dir"
  if ! git -c safe.directory="$SHIPLOG_TEST_ROOT" -C "$SHIPLOG_TEST_ROOT" remote add stray "$stray_remote_dir" >/dev/null 2>&1; then
    rm -rf "$stray_remote_dir"
    skip "caller repository is read-only; skipping remote restore coverage"
  fi
  trap '(
    git -c safe.directory="'$SHIPLOG_TEST_ROOT'" -C "$SHIPLOG_TEST_ROOT" remote remove stray >/dev/null 2>&1 || true
    rm -rf "$stray_remote_dir"
  )' RETURN
  SHIPLOG_TEMP_REMOTE_DIRS+=("$stray_remote_dir")

  if [ "$ORIG_HAVE_ORIGIN" -eq 1 ]; then
    (
      cd "$SHIPLOG_TEST_ROOT" || exit 1
      git config --add remote.origin.fetch '+refs/tags/*:refs/remotes/origin/tags' || exit 1
      git config --add remote.origin.pushurl 'ssh://example/push' || exit 1
      git config --add remote.origin.url 'ssh://example/extra' || exit 1
    )
  fi

  REMOTE_RESTORE_SKIPPED=1
  shiplog_standard_teardown

  # Verify remotes restored to their pre-test state
  local current_remotes
  current_remotes=$(git remote)
  [ "$current_remotes" = "$ORIG_REMOTE_LIST" ]

  if [ "$ORIG_HAVE_ORIGIN" -eq 1 ]; then
    run git config --get-all remote.origin.url
    [ "$status" -eq 0 ]
    [ "$output" = "$ORIG_ORIGIN_URLS" ]

    run git config --get-all remote.origin.fetch
    [ "$status" -eq 0 ]
    [ "$output" = "$ORIG_ORIGIN_FETCHES" ]

    run git config --get-all remote.origin.pushurl
    if [ -n "$ORIG_ORIGIN_PUSHURLS" ]; then
      [ "$status" -eq 0 ]
      [ "$output" = "$ORIG_ORIGIN_PUSHURLS" ]
    else
      [ "$status" -ne 0 ]
    fi
  else
    run bash -c 'git remote | grep -qx origin'
    [ "$status" -ne 0 ]
  fi
}
