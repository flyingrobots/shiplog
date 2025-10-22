#!/usr/bin/env bats

load helpers/common

bats_require_minimum_version 1.5.0

setup() {
  shiplog_reset_remote_snapshot_state >/dev/null 2>&1 || true
  _RESTORE_ORIG_TEST_ROOT="${SHIPLOG_TEST_ROOT:-}"
  _RESTORE_TEST_ROOT="$(mktemp -d)"
  export SHIPLOG_TEST_ROOT="$_RESTORE_TEST_ROOT"
  export LC_ALL=C
  shiplog_git_caller init -q
  shiplog_git_caller config user.name "Shiplog Tester"
  shiplog_git_caller config user.email "shiplog-tester@example.com"
}

teardown() {
  shiplog_reset_remote_snapshot_state >/dev/null 2>&1 || true
  if [ -n "${_RESTORE_TEST_ROOT:-}" ] && [ -d "$_RESTORE_TEST_ROOT" ]; then
    chmod -R u+w "$_RESTORE_TEST_ROOT" >/dev/null 2>&1 || true
    rm -rf "$_RESTORE_TEST_ROOT"
  fi
  if [ -n "${_RESTORE_ORIG_TEST_ROOT:-}" ]; then
    export SHIPLOG_TEST_ROOT="$_RESTORE_ORIG_TEST_ROOT"
  else
    unset SHIPLOG_TEST_ROOT
  fi
  unset _RESTORE_TEST_ROOT
  unset _RESTORE_ORIG_TEST_ROOT
  unset LC_ALL
}

@test "restore removes unexpected remotes" {
  local remote="shimtest-${BATS_TEST_NUMBER}"
  shiplog_reset_remote_snapshot_state
  shiplog_snapshot_caller_repo_state
  shiplog_git_caller remote add "$remote" https://example.invalid/original.git

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  echo "$output" | grep -qxF "$remote"

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -qxF "$remote"

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore rebuilds multi-url remote configuration" {
  local remote="shimtest-${BATS_TEST_NUMBER}"
  shiplog_reset_remote_snapshot_state

  shiplog_git_caller remote add "$remote" https://example.invalid/primary.git
  shiplog_git_caller remote set-url --add "$remote" ssh://example.invalid/secondary.git
  shiplog_git_caller remote set-url --push "$remote" ssh://push.invalid/primary.git
  shiplog_git_caller remote set-url --push --add "$remote" ssh://push.invalid/secondary.git
  shiplog_git_caller config --add "remote.${remote}.fetch" "+refs/heads/*:refs/remotes/${remote}/*"
  shiplog_git_caller config --add "remote.${remote}.mirror" true

  local before_urls before_pushurls before_fetch before_mirror
  before_urls="$(shiplog_git_caller config --get-all remote.${remote}.url 2>/dev/null || true)"
  before_pushurls="$(shiplog_git_caller config --get-all remote.${remote}.pushurl 2>/dev/null || true)"
  before_fetch="$(shiplog_git_caller config --get-all remote.${remote}.fetch 2>/dev/null || true)"
  before_mirror="$(shiplog_git_caller config remote.${remote}.mirror 2>/dev/null || true)"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote remove "$remote"
  shiplog_git_caller remote add "$remote" https://example.invalid/nope.git
  shiplog_git_caller config --add "remote.${remote}.fetch" "+refs/tags/*:refs/tags/*"

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after_urls after_pushurls after_fetch after_mirror
  after_urls="$(shiplog_git_caller config --get-all remote.${remote}.url 2>/dev/null || true)"
  after_pushurls="$(shiplog_git_caller config --get-all remote.${remote}.pushurl 2>/dev/null || true)"
  after_fetch="$(shiplog_git_caller config --get-all remote.${remote}.fetch 2>/dev/null || true)"
  after_mirror="$(shiplog_git_caller config remote.${remote}.mirror 2>/dev/null || true)"
  [ "$before_urls" = "$after_urls" ]
  [ "$before_pushurls" = "$after_pushurls" ]
  [ "$before_fetch" = "$after_fetch" ]
  [ "$before_mirror" = "$after_mirror" ]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore skips with warning when .git/config is read-only" {
  local remote="shimtest-${BATS_TEST_NUMBER}"
  shiplog_reset_remote_snapshot_state
  shiplog_git_caller remote add "$remote" https://example.invalid/readonly.git
  shiplog_snapshot_caller_repo_state
  shiplog_git_caller remote remove "$remote"
  export SHIPLOG_FORCE_REMOTE_RESTORE_SKIP=1

  run --separate-stderr shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]
  echo "$stderr" | grep -q "Skipping remote restore: config is read-only"

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  unset SHIPLOG_FORCE_REMOTE_RESTORE_SKIP
}

@test "snapshot captures empty remote list" {
  local remote
  shiplog_reset_remote_snapshot_state
  shiplog_git_caller remote 2>/dev/null | while IFS= read -r remote; do
    [ -n "$remote" ] || continue
    shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
  done

  shiplog_snapshot_caller_repo_state
  local rc=$?
  [ "$rc" -eq 0 ]
  [ "$SHIPLOG_CALLER_REPO_CAPTURED" -eq 1 ]
  [ "${#SHIPLOG_ORIG_REMOTE_ORDER[@]}" -eq 0 ]
}

@test "snapshot captures single remote with basic config" {
  local remote="shimtest-single-${BATS_TEST_NUMBER}"
  shiplog_reset_remote_snapshot_state
  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
  shiplog_git_caller remote add "$remote" https://example.invalid/single.git

  shiplog_snapshot_caller_repo_state
  local rc=$?
  [ "$rc" -eq 0 ]
  [ "$SHIPLOG_CALLER_REPO_CAPTURED" -eq 1 ]
  [ "${#SHIPLOG_ORIG_REMOTE_ORDER[@]}" -eq 1 ]
  [ "${SHIPLOG_ORIG_REMOTE_ORDER[0]}" = "$remote" ]
  grep -qF "remote.${remote}.url " <<<"${SHIPLOG_ORIG_REMOTES_CONFIG[$remote]}"

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "snapshot captures multiple remotes in order" {
  local remote1="alpha-${BATS_TEST_NUMBER}"
  local remote2="beta-${BATS_TEST_NUMBER}"
  local remote3="gamma-${BATS_TEST_NUMBER}"
  shiplog_reset_remote_snapshot_state

  shiplog_git_caller remote add "$remote1" https://example.invalid/alpha.git
  shiplog_git_caller remote add "$remote2" https://example.invalid/beta.git
  shiplog_git_caller remote add "$remote3" https://example.invalid/gamma.git

  shiplog_snapshot_caller_repo_state
  local rc=$?
  [ "$rc" -eq 0 ]
  [ "${#SHIPLOG_ORIG_REMOTE_ORDER[@]}" -eq 3 ]
  [ "${SHIPLOG_ORIG_REMOTE_ORDER[0]}" = "$remote1" ]
  [ "${SHIPLOG_ORIG_REMOTE_ORDER[1]}" = "$remote2" ]
  [ "${SHIPLOG_ORIG_REMOTE_ORDER[2]}" = "$remote3" ]

  shiplog_git_caller remote remove "$remote1" >/dev/null 2>&1 || true
  shiplog_git_caller remote remove "$remote2" >/dev/null 2>&1 || true
  shiplog_git_caller remote remove "$remote3" >/dev/null 2>&1 || true
}

@test "snapshot captures remote with special characters in name" {
  local remote="test-remote.with_special-chars-${BATS_TEST_NUMBER}"
  shiplog_reset_remote_snapshot_state
  shiplog_git_caller remote add "$remote" https://example.invalid/special.git

  shiplog_snapshot_caller_repo_state
  local rc=$?
  [ "$rc" -eq 0 ]
  [ "${SHIPLOG_ORIG_REMOTE_ORDER[0]}" = "$remote" ]
  grep -qF "remote.${remote}.url " <<<"${SHIPLOG_ORIG_REMOTES_CONFIG[$remote]}"

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "snapshot fails gracefully when not in git repository" {
  local temp_dir original_root
  temp_dir="$(mktemp -d)"
  original_root="${SHIPLOG_TEST_ROOT}"
  export SHIPLOG_TEST_ROOT="$temp_dir"

  run --separate-stderr shiplog_snapshot_caller_repo_state
  [ "$status" -ne 0 ]
  echo "$stderr" | grep -q "not a git repository"

  rm -rf "$temp_dir"
  export SHIPLOG_TEST_ROOT="$original_root"
}

@test "reset clears all snapshot state variables" {
  local remote="shimtest-reset-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/test.git
  shiplog_snapshot_caller_repo_state

  [ "$SHIPLOG_CALLER_REPO_CAPTURED" -eq 1 ]
  [ "${#SHIPLOG_ORIG_REMOTE_ORDER[@]}" -gt 0 ]

  shiplog_reset_remote_snapshot_state
  [ "$SHIPLOG_CALLER_REPO_CAPTURED" -eq 0 ]
  [ "${#SHIPLOG_ORIG_REMOTE_ORDER[@]}" -eq 0 ]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore is no-op when no snapshot captured" {
  local remote="shimtest-noop-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/noop.git

  shiplog_reset_remote_snapshot_state

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  echo "$output" | grep -qxF "$remote"

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore handles empty snapshot correctly" {
  local remote="shimtest-empty-${BATS_TEST_NUMBER}"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote add "$remote" https://example.invalid/added.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -qxF "$remote"
}

@test "restore preserves remote order" {
  local remote1="first-${BATS_TEST_NUMBER}"
  local remote2="second-${BATS_TEST_NUMBER}"
  local remote3="third-${BATS_TEST_NUMBER}"

  shiplog_git_caller remote add "$remote1" https://example.invalid/first.git
  shiplog_git_caller remote add "$remote2" https://example.invalid/second.git
  shiplog_git_caller remote add "$remote3" https://example.invalid/third.git

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote remove "$remote1"
  shiplog_git_caller remote remove "$remote2"
  shiplog_git_caller remote remove "$remote3"
  shiplog_git_caller remote add "$remote3" https://example.invalid/wrong.git
  shiplog_git_caller remote add "$remote1" https://example.invalid/wrong.git
  shiplog_git_caller remote add "$remote2" https://example.invalid/wrong.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local url1 url2 url3
  url1="$(shiplog_git_caller config --get remote.$remote1.url)"
  url2="$(shiplog_git_caller config --get remote.$remote2.url)"
  url3="$(shiplog_git_caller config --get remote.$remote3.url)"
  [ "$url1" = "https://example.invalid/first.git" ]
  [ "$url2" = "https://example.invalid/second.git" ]
  [ "$url3" = "https://example.invalid/third.git" ]

  local n1 n2 n3
  n1="$(grep -nF "[remote \"$remote1\"]" "$SHIPLOG_TEST_ROOT/.git/config" | head -n1 | cut -d: -f1)"
  n2="$(grep -nF "[remote \"$remote2\"]" "$SHIPLOG_TEST_ROOT/.git/config" | head -n1 | cut -d: -f1)"
  n3="$(grep -nF "[remote \"$remote3\"]" "$SHIPLOG_TEST_ROOT/.git/config" | head -n1 | cut -d: -f1)"
  [ -n "$n1" ] && [ -n "$n2" ] && [ -n "$n3" ]
  [ "$n1" -lt "$n2" ] && [ "$n2" -lt "$n3" ]

  shiplog_git_caller remote remove "$remote1" >/dev/null 2>&1 || true
  shiplog_git_caller remote remove "$remote2" >/dev/null 2>&1 || true
  shiplog_git_caller remote remove "$remote3" >/dev/null 2>&1 || true
}

@test "restore handles remote with multiple fetch specs" {
  local remote="shimtest-fetch-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/multi.git
  shiplog_git_caller config --add "remote.${remote}.fetch" "+refs/heads/main:refs/remotes/${remote}/main"
  shiplog_git_caller config --add "remote.${remote}.fetch" "+refs/heads/dev:refs/remotes/${remote}/dev"
  shiplog_git_caller config --add "remote.${remote}.fetch" "+refs/tags/*:refs/tags/*"

  local before
  before="$(shiplog_git_caller config --get-all remote.${remote}.fetch)"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote remove "$remote"
  shiplog_git_caller remote add "$remote" https://example.invalid/different.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after
  after="$(shiplog_git_caller config --get-all remote.${remote}.fetch)"
  [ "$before" = "$after" ]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore handles remote with multiple pushurls" {
  local remote="shimtest-push-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/fetch.git
  shiplog_git_caller remote set-url --push "$remote" ssh://push1.invalid/repo.git
  shiplog_git_caller remote set-url --push --add "$remote" ssh://push2.invalid/repo.git
  shiplog_git_caller remote set-url --push --add "$remote" ssh://push3.invalid/repo.git

  local before
  before="$(shiplog_git_caller config --get-all remote.${remote}.pushurl)"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote remove "$remote"
  shiplog_git_caller remote add "$remote" https://example.invalid/wrong.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after
  after="$(shiplog_git_caller config --get-all remote.${remote}.pushurl)"
  [ "$before" = "$after" ]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore handles remote with custom config keys" {
  local remote="shimtest-custom-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/custom.git
  shiplog_git_caller config "remote.${remote}.tagOpt" "--no-tags"
  shiplog_git_caller config "remote.${remote}.prune" "true"
  shiplog_git_caller config "remote.${remote}.skipDefaultUpdate" "true"

  local before_urls before_pushurls before_fetch before_tagopt before_prune before_skip before_custom
  before_urls="$(shiplog_git_caller config --get-all remote.${remote}.url 2>/dev/null || true)"
  before_pushurls="$(shiplog_git_caller config --get-all remote.${remote}.pushurl 2>/dev/null || true)"
  before_fetch="$(shiplog_git_caller config --get-all remote.${remote}.fetch 2>/dev/null || true)"
  before_tagopt="$(shiplog_git_caller config remote.${remote}.tagOpt 2>/dev/null || true)"
  before_prune="$(shiplog_git_caller config remote.${remote}.prune 2>/dev/null || true)"
  before_skip="$(shiplog_git_caller config remote.${remote}.skipDefaultUpdate 2>/dev/null || true)"
  before_custom="$(shiplog_git_caller config --get-all remote.${remote}.customKey 2>/dev/null || true)"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote remove "$remote"
  shiplog_git_caller remote add "$remote" https://example.invalid/plain.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after_urls after_pushurls after_fetch after_tagopt after_prune after_skip after_custom
  after_urls="$(shiplog_git_caller config --get-all remote.${remote}.url 2>/dev/null || true)"
  after_pushurls="$(shiplog_git_caller config --get-all remote.${remote}.pushurl 2>/dev/null || true)"
  after_fetch="$(shiplog_git_caller config --get-all remote.${remote}.fetch 2>/dev/null || true)"
  after_tagopt="$(shiplog_git_caller config remote.${remote}.tagOpt 2>/dev/null || true)"
  after_prune="$(shiplog_git_caller config remote.${remote}.prune 2>/dev/null || true)"
  after_skip="$(shiplog_git_caller config remote.${remote}.skipDefaultUpdate 2>/dev/null || true)"
  after_custom="$(shiplog_git_caller config --get-all remote.${remote}.customKey 2>/dev/null || true)"
  [ "$before_urls" = "$after_urls" ]
  [ "$before_pushurls" = "$after_pushurls" ]
  [ "$before_fetch" = "$after_fetch" ]
  [ "$before_tagopt" = "$after_tagopt" ]
  [ "$before_prune" = "$after_prune" ]
  [ "$before_skip" = "$after_skip" ]
  [ "$before_custom" = "$after_custom" ]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore removes multiple unexpected remotes" {
  local remote1="expected-${BATS_TEST_NUMBER}"
  local remote2="unexpected1-${BATS_TEST_NUMBER}"
  local remote3="unexpected2-${BATS_TEST_NUMBER}"

  shiplog_git_caller remote add "$remote1" https://example.invalid/expected.git
  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote add "$remote2" https://example.invalid/unexpected1.git
  shiplog_git_caller remote add "$remote3" https://example.invalid/unexpected2.git

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  echo "$output" | grep -qxF "$remote2"
  echo "$output" | grep -qxF "$remote3"

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -qxF "$remote2"
  ! echo "$output" | grep -qxF "$remote3"
  echo "$output" | grep -qxF "$remote1"

  shiplog_git_caller remote remove "$remote1" >/dev/null 2>&1 || true
}

@test "restore is idempotent" {
  local remote="shimtest-idempotent-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/idempotent.git
  shiplog_git_caller config "remote.${remote}.fetch" "+refs/heads/*:refs/remotes/${remote}/*"

  local before_urls before_pushurls before_fetch before_tagopt before_prune before_skip before_mirror
  before_urls="$(shiplog_git_caller config --get-all remote.${remote}.url 2>/dev/null || true)"
  before_pushurls="$(shiplog_git_caller config --get-all remote.${remote}.pushurl 2>/dev/null || true)"
  before_fetch="$(shiplog_git_caller config --get-all remote.${remote}.fetch 2>/dev/null || true)"
  before_tagopt="$(shiplog_git_caller config remote.${remote}.tagOpt 2>/dev/null || true)"
  before_prune="$(shiplog_git_caller config remote.${remote}.prune 2>/dev/null || true)"
  before_skip="$(shiplog_git_caller config remote.${remote}.skipDefaultUpdate 2>/dev/null || true)"
  before_mirror="$(shiplog_git_caller config remote.${remote}.mirror 2>/dev/null || true)"

  shiplog_snapshot_caller_repo_state

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after_first_urls after_first_pushurls after_first_fetch after_first_tagopt after_first_prune after_first_skip after_first_mirror
  after_first_urls="$(shiplog_git_caller config --get-all remote.${remote}.url 2>/dev/null || true)"
  after_first_pushurls="$(shiplog_git_caller config --get-all remote.${remote}.pushurl 2>/dev/null || true)"
  after_first_fetch="$(shiplog_git_caller config --get-all remote.${remote}.fetch 2>/dev/null || true)"
  after_first_tagopt="$(shiplog_git_caller config remote.${remote}.tagOpt 2>/dev/null || true)"
  after_first_prune="$(shiplog_git_caller config remote.${remote}.prune 2>/dev/null || true)"
  after_first_skip="$(shiplog_git_caller config remote.${remote}.skipDefaultUpdate 2>/dev/null || true)"
  after_first_mirror="$(shiplog_git_caller config remote.${remote}.mirror 2>/dev/null || true)"
  [ "$before_urls" = "$after_first_urls" ]
  [ "$before_pushurls" = "$after_first_pushurls" ]
  [ "$before_fetch" = "$after_first_fetch" ]
  [ "$before_tagopt" = "$after_first_tagopt" ]
  [ "$before_prune" = "$after_first_prune" ]
  [ "$before_skip" = "$after_first_skip" ]
  [ "$before_mirror" = "$after_first_mirror" ]

  shiplog_git_caller config "remote.${remote}.tagOpt" "--tags"
  shiplog_snapshot_caller_repo_state
  shiplog_git_caller remote set-url "$remote" https://example.invalid/modified.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local final_urls final_pushurls final_fetch final_tagopt final_prune final_skip final_mirror
  final_urls="$(shiplog_git_caller config --get-all remote.${remote}.url 2>/dev/null || true)"
  final_pushurls="$(shiplog_git_caller config --get-all remote.${remote}.pushurl 2>/dev/null || true)"
  final_fetch="$(shiplog_git_caller config --get-all remote.${remote}.fetch 2>/dev/null || true)"
  final_tagopt="$(shiplog_git_caller config remote.${remote}.tagOpt 2>/dev/null || true)"
  final_prune="$(shiplog_git_caller config remote.${remote}.prune 2>/dev/null || true)"
  final_skip="$(shiplog_git_caller config remote.${remote}.skipDefaultUpdate 2>/dev/null || true)"
  final_mirror="$(shiplog_git_caller config remote.${remote}.mirror 2>/dev/null || true)"
  [ "$before_urls" = "$final_urls" ]
  [ "$before_pushurls" = "$final_pushurls" ]
  [ "$before_fetch" = "$final_fetch" ]
  [ "$final_tagopt" = "--tags" ]
  [ "$before_prune" = "$final_prune" ]
  [ "$before_skip" = "$final_skip" ]
  [ "$before_mirror" = "$final_mirror" ]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore handles remote with no URL configured" {
  local remote="shimtest-no-url-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/temp.git

  shiplog_git_caller config --unset-all "remote.${remote}.url" >/dev/null 2>&1 || true

  shiplog_snapshot_caller_repo_state
  [ "$?" -eq 0 ]

  shiplog_git_caller remote remove "$remote"

  run --separate-stderr shiplog_restore_caller_remotes
  [ "$status" -ne 0 ]
  echo "$stderr" | grep -q "Missing URL"
}

@test "git_caller executes commands in correct directory" {
  local remote="shimtest-gitcaller-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
  run shiplog_git_caller remote add "$remote" https://example.invalid/test.git
  [ "$status" -eq 0 ]

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  echo "$output" | grep -qxF "$remote"

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "git_caller respects safe.directory config" {
  run shiplog_git_caller status --short
  [ "$status" -eq 0 ]
}

@test "helper_error outputs to stderr" {
  run --separate-stderr shiplog_helper_error "test error message"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  echo "$stderr" | grep -q "ERROR: test error message"
}

@test "helper_error formats multiple arguments" {
  run --separate-stderr shiplog_helper_error "multiple" "args" "test"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  echo "$stderr" | grep -q "ERROR: multiple args test"
}

@test "restore skip flag triggers read-only handling" {
  export SHIPLOG_FORCE_REMOTE_RESTORE_SKIP=1
  shiplog_snapshot_caller_repo_state

  run --separate-stderr shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]
  echo "$stderr" | grep -q "Skipping remote restore: config is read-only"

  unset SHIPLOG_FORCE_REMOTE_RESTORE_SKIP
}

@test "restore_exec returns success for valid commands" {
  local remote="shimtest-exec-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true

  run shiplog_restore_exec "test context" remote add "$remote" https://example.invalid/test.git
  [ "$status" -eq 0 ]

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  echo "$output" | grep -qxF "$remote"

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore_exec propagates command failures" {
  local remote="shimtest-fail-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/existing.git

  run --separate-stderr shiplog_restore_exec "test context" remote add "$remote" https://example.invalid/duplicate.git
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  echo "$stderr" | grep -q "test context"

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "snapshot handles remotes with dots in name" {
  local remote="remote.with.dots-${BATS_TEST_NUMBER}"
  shiplog_reset_remote_snapshot_state
  shiplog_git_caller remote add "$remote" https://example.invalid/dots.git

  shiplog_snapshot_caller_repo_state
  [ "$?" -eq 0 ]
  grep -qF "remote.${remote}.url " <<<"${SHIPLOG_ORIG_REMOTES_CONFIG[$remote]}"

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "snapshot handles remotes with brackets in name" {
  local remote="remote[bracket]-${BATS_TEST_NUMBER}"
  shiplog_reset_remote_snapshot_state
  if shiplog_git_caller remote add "$remote" https://example.invalid/bracket.git 2>/dev/null; then
    shiplog_snapshot_caller_repo_state
    [ "$?" -eq 0 ]
    grep -qF "remote.${remote}.url " <<<"${SHIPLOG_ORIG_REMOTES_CONFIG[$remote]}"
    shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
  else
    skip "Git does not support this remote name format"
  fi
}

@test "restore handles complex multi-remote scenario" {
  local remote1="prod-${BATS_TEST_NUMBER}"
  local remote2="staging-${BATS_TEST_NUMBER}"
  local remote3="dev-${BATS_TEST_NUMBER}"

  shiplog_git_caller remote add "$remote1" https://example.invalid/prod-fetch.git
  shiplog_git_caller remote set-url --add "$remote1" https://example.invalid/prod-fetch2.git
  shiplog_git_caller remote set-url --push "$remote1" ssh://prod-push.invalid/repo.git
  shiplog_git_caller config "remote.${remote1}.tagOpt" "--no-tags"

  shiplog_git_caller remote add "$remote2" https://example.invalid/staging.git
  shiplog_git_caller config --add "remote.${remote2}.fetch" "+refs/heads/main:refs/remotes/${remote2}/main"
  shiplog_git_caller config "remote.${remote2}.prune" "true"

  shiplog_git_caller remote add "$remote3" https://example.invalid/dev.git

  local prod_before_urls prod_before_pushurls prod_before_fetch prod_before_mirror
  local staging_before_urls staging_before_pushurls staging_before_fetch staging_before_mirror
  local dev_before_urls dev_before_pushurls dev_before_fetch dev_before_mirror
  prod_before_urls="$(shiplog_git_caller config --get-all remote.${remote1}.url 2>/dev/null || true)"
  prod_before_pushurls="$(shiplog_git_caller config --get-all remote.${remote1}.pushurl 2>/dev/null || true)"
  prod_before_fetch="$(shiplog_git_caller config --get-all remote.${remote1}.fetch 2>/dev/null || true)"
  prod_before_mirror="$(shiplog_git_caller config remote.${remote1}.mirror 2>/dev/null || true)"
  staging_before_urls="$(shiplog_git_caller config --get-all remote.${remote2}.url 2>/dev/null || true)"
  staging_before_pushurls="$(shiplog_git_caller config --get-all remote.${remote2}.pushurl 2>/dev/null || true)"
  staging_before_fetch="$(shiplog_git_caller config --get-all remote.${remote2}.fetch 2>/dev/null || true)"
  staging_before_mirror="$(shiplog_git_caller config remote.${remote2}.mirror 2>/dev/null || true)"
  dev_before_urls="$(shiplog_git_caller config --get-all remote.${remote3}.url 2>/dev/null || true)"
  dev_before_pushurls="$(shiplog_git_caller config --get-all remote.${remote3}.pushurl 2>/dev/null || true)"
  dev_before_fetch="$(shiplog_git_caller config --get-all remote.${remote3}.fetch 2>/dev/null || true)"
  dev_before_mirror="$(shiplog_git_caller config remote.${remote3}.mirror 2>/dev/null || true)"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote remove "$remote1"
  shiplog_git_caller remote remove "$remote2"
  shiplog_git_caller remote remove "$remote3"
  shiplog_git_caller remote add "$remote1" https://example.invalid/wrong.git
  shiplog_git_caller remote add "$remote2" https://example.invalid/wrong.git
  shiplog_git_caller remote add extra-remote https://example.invalid/extra.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local prod_after_urls prod_after_pushurls prod_after_fetch prod_after_mirror
  local staging_after_urls staging_after_pushurls staging_after_fetch staging_after_mirror
  local dev_after_urls dev_after_pushurls dev_after_fetch dev_after_mirror
  prod_after_urls="$(shiplog_git_caller config --get-all remote.${remote1}.url 2>/dev/null || true)"
  prod_after_pushurls="$(shiplog_git_caller config --get-all remote.${remote1}.pushurl 2>/dev/null || true)"
  prod_after_fetch="$(shiplog_git_caller config --get-all remote.${remote1}.fetch 2>/dev/null || true)"
  prod_after_mirror="$(shiplog_git_caller config remote.${remote1}.mirror 2>/dev/null || true)"
  staging_after_urls="$(shiplog_git_caller config --get-all remote.${remote2}.url 2>/dev/null || true)"
  staging_after_pushurls="$(shiplog_git_caller config --get-all remote.${remote2}.pushurl 2>/dev/null || true)"
  staging_after_fetch="$(shiplog_git_caller config --get-all remote.${remote2}.fetch 2>/dev/null || true)"
  staging_after_mirror="$(shiplog_git_caller config remote.${remote2}.mirror 2>/dev/null || true)"
  dev_after_urls="$(shiplog_git_caller config --get-all remote.${remote3}.url 2>/dev/null || true)"
  dev_after_pushurls="$(shiplog_git_caller config --get-all remote.${remote3}.pushurl 2>/dev/null || true)"
  dev_after_fetch="$(shiplog_git_caller config --get-all remote.${remote3}.fetch 2>/dev/null || true)"
  dev_after_mirror="$(shiplog_git_caller config remote.${remote3}.mirror 2>/dev/null || true)"

  [ "$prod_before_urls" = "$prod_after_urls" ]
  [ "$prod_before_pushurls" = "$prod_after_pushurls" ]
  [ "$prod_before_fetch" = "$prod_after_fetch" ]
  [ "$prod_before_mirror" = "$prod_after_mirror" ]
  [ "$staging_before_urls" = "$staging_after_urls" ]
  [ "$staging_before_pushurls" = "$staging_after_pushurls" ]
  [ "$staging_before_fetch" = "$staging_after_fetch" ]
  [ "$staging_before_mirror" = "$staging_after_mirror" ]
  [ "$dev_before_urls" = "$dev_after_urls" ]
  [ "$dev_before_pushurls" = "$dev_after_pushurls" ]
  [ "$dev_before_fetch" = "$dev_after_fetch" ]
  [ "$dev_before_mirror" = "$dev_after_mirror" ]

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -qxF "extra-remote"

  shiplog_git_caller remote remove "$remote1" >/dev/null 2>&1 || true
  shiplog_git_caller remote remove "$remote2" >/dev/null 2>&1 || true
  shiplog_git_caller remote remove "$remote3" >/dev/null 2>&1 || true
}

@test "restore handles URL with special characters" {
  local remote="shimtest-url-${BATS_TEST_NUMBER}"
  local url="https://user%40name:p%40ss@example.invalid:8080/path/to/repo.git?query=value#fragment"

  shiplog_git_caller remote add "$remote" "$url"

  local before
  before="$(shiplog_git_caller config --get remote.${remote}.url)"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote set-url "$remote" https://example.invalid/wrong.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after
  after="$(shiplog_git_caller config --get remote.${remote}.url)"
  [ "$before" = "$after" ]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "snapshot and restore preserve exact whitespace in config values" {
  local remote="shimtest-whitespace-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/test.git
  shiplog_git_caller config "remote.${remote}.customKey" "value with  spaces"

  local before
  before="$(shiplog_git_caller config --get remote.${remote}.customKey)"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller config "remote.${remote}.customKey" "different value"

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after
  after="$(shiplog_git_caller config --get remote.${remote}.customKey)"
  [ "$before" = "$after" ]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore clears snapshot state after completion" {
  local remote="shimtest-clear-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/test.git

  shiplog_snapshot_caller_repo_state
  [ "$SHIPLOG_CALLER_REPO_CAPTURED" -eq 1 ]
  [ "${#SHIPLOG_ORIG_REMOTE_ORDER[@]}" -gt 0 ]
  [ "${#SHIPLOG_ORIG_REMOTES_CONFIG[@]}" -gt 0 ]

  shiplog_restore_caller_remotes
  local rc=$?
  [ "$rc" -eq 0 ]
  [ "$SHIPLOG_CALLER_REPO_CAPTURED" -eq 0 ]
  [ "${#SHIPLOG_ORIG_REMOTE_ORDER[@]}" -eq 0 ]
  [ "${#SHIPLOG_ORIG_REMOTES_CONFIG[@]}" -eq 0 ]
  # Paranoid guard: Bash 5.x has occasional associative array bugs where length checks
  # pass even though keys remain; fail loudly if we ever observe that inconsistent state.
  local key
  for key in "${!SHIPLOG_ORIG_REMOTES_CONFIG[@]}"; do
    echo "Expected empty SHIPLOG_ORIG_REMOTES_CONFIG but found key: $key" >&2
    false
  done

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore handles mixed snapshot and manual remote operations" {
  local remote1="auto-${BATS_TEST_NUMBER}"
  local remote2="manual-${BATS_TEST_NUMBER}"

  shiplog_git_caller remote add "$remote1" https://example.invalid/auto.git
  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote add "$remote2" https://example.invalid/manual.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  echo "$output" | grep -qxF "$remote1"
  ! echo "$output" | grep -qxF "$remote2"

  shiplog_git_caller remote remove "$remote1" >/dev/null 2>&1 || true
}

@test "multiple snapshots can be taken sequentially" {
  local remote1="first-${BATS_TEST_NUMBER}"
  local remote2="second-${BATS_TEST_NUMBER}"

  shiplog_reset_remote_snapshot_state
  shiplog_git_caller remote add "$remote1" https://example.invalid/first.git
  shiplog_snapshot_caller_repo_state
  local first_count="${#SHIPLOG_ORIG_REMOTE_ORDER[@]}"

  shiplog_git_caller remote add "$remote2" https://example.invalid/second.git
  shiplog_snapshot_caller_repo_state
  local second_count="${#SHIPLOG_ORIG_REMOTE_ORDER[@]}"

  [ "$first_count" -eq 1 ]
  [ "$second_count" -eq 2 ]

  shiplog_git_caller remote remove "$remote1" >/dev/null 2>&1 || true
  shiplog_git_caller remote remove "$remote2" >/dev/null 2>&1 || true
}

@test "restore handles remote name with regex metacharacters" {
  local remote="remote\$special*chars?-${BATS_TEST_NUMBER}"

  if shiplog_git_caller remote add "$remote" https://example.invalid/special.git 2>/dev/null; then
    shiplog_snapshot_caller_repo_state
    shiplog_git_caller remote remove "$remote"

    run shiplog_restore_caller_remotes
    [ "$status" -eq 0 ]

    run shiplog_git_caller remote
    [ "$status" -eq 0 ]
    echo "$output" | grep -qxF "$remote"

    run shiplog_git_caller remote get-url "$remote"
    [ "$status" -eq 0 ]
    [ "$output" = "https://example.invalid/special.git" ]

    run shiplog_git_caller config --get-all "remote.${remote}.url"
    [ "$status" -eq 0 ]
    [ "$output" = "https://example.invalid/special.git" ]

    shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
  else
    skip "Git does not support this remote name format"
  fi
}

@test "restore maintains remote configuration after failed git operation" {
  local remote="shimtest-maintain-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/test.git
  shiplog_git_caller config "remote.${remote}.important" "true"

  local before_urls before_pushurls before_fetch before_tagopt before_prune before_skip before_mirror before_important
  before_urls="$(shiplog_git_caller config --get-all remote.${remote}.url 2>/dev/null || true)"
  before_pushurls="$(shiplog_git_caller config --get-all remote.${remote}.pushurl 2>/dev/null || true)"
  before_fetch="$(shiplog_git_caller config --get-all remote.${remote}.fetch 2>/dev/null || true)"
  before_tagopt="$(shiplog_git_caller config remote.${remote}.tagOpt 2>/dev/null || true)"
  before_prune="$(shiplog_git_caller config remote.${remote}.prune 2>/dev/null || true)"
  before_skip="$(shiplog_git_caller config remote.${remote}.skipDefaultUpdate 2>/dev/null || true)"
  before_mirror="$(shiplog_git_caller config remote.${remote}.mirror 2>/dev/null || true)"
  before_important="$(shiplog_git_caller config remote.${remote}.important 2>/dev/null || true)"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote set-url "$remote" https://example.invalid/changed.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after_urls after_pushurls after_fetch after_tagopt after_prune after_skip after_mirror after_important
  after_urls="$(shiplog_git_caller config --get-all remote.${remote}.url 2>/dev/null || true)"
  after_pushurls="$(shiplog_git_caller config --get-all remote.${remote}.pushurl 2>/dev/null || true)"
  after_fetch="$(shiplog_git_caller config --get-all remote.${remote}.fetch 2>/dev/null || true)"
  after_tagopt="$(shiplog_git_caller config remote.${remote}.tagOpt 2>/dev/null || true)"
  after_prune="$(shiplog_git_caller config remote.${remote}.prune 2>/dev/null || true)"
  after_skip="$(shiplog_git_caller config remote.${remote}.skipDefaultUpdate 2>/dev/null || true)"
  after_mirror="$(shiplog_git_caller config remote.${remote}.mirror 2>/dev/null || true)"
  after_important="$(shiplog_git_caller config remote.${remote}.important 2>/dev/null || true)"
  [ "$before_urls" = "$after_urls" ]
  [ "$before_pushurls" = "$after_pushurls" ]
  [ "$before_fetch" = "$after_fetch" ]
  [ "$before_tagopt" = "$after_tagopt" ]
  [ "$before_prune" = "$after_prune" ]
  [ "$before_skip" = "$after_skip" ]
  [ "$before_mirror" = "$after_mirror" ]
  [ "$before_important" = "$after_important" ]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}
