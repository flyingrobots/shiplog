#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_reset_remote_snapshot_state >/dev/null 2>&1 || true
  _RESTORE_ORIG_TEST_ROOT="${SHIPLOG_TEST_ROOT:-}"
  _RESTORE_TEST_ROOT="$(mktemp -d)"
  export SHIPLOG_TEST_ROOT="$_RESTORE_TEST_ROOT"
  export LC_ALL=C
  git -C "$SHIPLOG_TEST_ROOT" init -q
  git -C "$SHIPLOG_TEST_ROOT" config user.name "Shiplog Tester"
  git -C "$SHIPLOG_TEST_ROOT" config user.email "shiplog-tester@example.com"
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
  local temp_repo
  temp_repo="$(mktemp -d)"
  (
    cd "$temp_repo"
    export SHIPLOG_TEST_ROOT="$temp_repo"
    export LC_ALL=C
    git init -q
    git config user.name "Shiplog Tester"
    git config user.email "shiplog-tester@example.com"
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
  )
  rm -rf "$temp_repo"
}

@test "restore rebuilds multi-url remote configuration" {
  local remote="shimtest-${BATS_TEST_NUMBER}"
  local temp_repo
  temp_repo="$(mktemp -d)"
  (
    cd "$temp_repo"
    export SHIPLOG_TEST_ROOT="$temp_repo"
    export LC_ALL=C
    git init -q
    git config user.name "Shiplog Tester"
    git config user.email "shiplog-tester@example.com"
    shiplog_reset_remote_snapshot_state

    shiplog_git_caller remote add "$remote" https://example.invalid/primary.git
    shiplog_git_caller remote set-url --add "$remote" ssh://example.invalid/secondary.git
    shiplog_git_caller remote set-url --push "$remote" ssh://push.invalid/primary.git
    shiplog_git_caller remote set-url --push --add "$remote" ssh://push.invalid/secondary.git
    shiplog_git_caller config --add "remote.${remote}.fetch" "+refs/heads/*:refs/remotes/${remote}/*"
    shiplog_git_caller config --add "remote.${remote}.mirror" true

    local before
    before="$(shiplog_git_caller config --get-regexp "^remote\.${remote}\." | sort)"

    shiplog_snapshot_caller_repo_state

    shiplog_git_caller remote remove "$remote"
    shiplog_git_caller remote add "$remote" https://example.invalid/nope.git
    shiplog_git_caller config --add "remote.${remote}.fetch" "+refs/tags/*:refs/tags/*"

    run shiplog_restore_caller_remotes
    [ "$status" -eq 0 ]

    local after
    after="$(shiplog_git_caller config --get-regexp "^remote\.${remote}\." | sort)"
    [ "$before" = "$after" ]
  )
  rm -rf "$temp_repo"
}

@test "restore skips with warning when .git/config is read-only" {
  local remote="shimtest-${BATS_TEST_NUMBER}"
  local temp_repo
  temp_repo="$(mktemp -d)"
  _RESTORE_READONLY_TMPDIR="$temp_repo"
  (
    cd "$temp_repo"
    export SHIPLOG_TEST_ROOT="$temp_repo"
    shiplog_git_caller init -q
    shiplog_git_caller remote add origin https://example.invalid/readonly.git
    # Container runs as root; force helper to exercise read-only skip path.
    export SHIPLOG_FORCE_REMOTE_RESTORE_SKIP=1
    shiplog_snapshot_caller_repo_state
    shiplog_git_caller remote remove origin
    chmod u-w .git/config
    run shiplog_restore_caller_remotes
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Skipping remote restore: config is read-only"
    run shiplog_git_caller remote
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  )
}

@test "snapshot captures empty remote list" {
  local remote
  shiplog_reset_remote_snapshot_state
  for remote in $(shiplog_git_caller remote 2>/dev/null); do
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
  [[ "${SHIPLOG_ORIG_REMOTES_CONFIG[$remote]}" == *"$remote.url"* ]]

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

  local seen_alpha=0 seen_beta=0 seen_gamma=0 remote
  for remote in "${SHIPLOG_ORIG_REMOTE_ORDER[@]}"; do
    if [ "$remote" = "$remote1" ]; then seen_alpha=1; fi
    if [ "$remote" = "$remote2" ]; then seen_beta=1; fi
    if [ "$remote" = "$remote3" ]; then seen_gamma=1; fi
  done
  [ "$seen_alpha" -eq 1 ]
  [ "$seen_beta" -eq 1 ]
  [ "$seen_gamma" -eq 1 ]

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
  [[ "${SHIPLOG_ORIG_REMOTES_CONFIG[$remote]}" == *"$remote.url"* ]]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "snapshot fails gracefully when not in git repository" {
  local temp_dir original_root
  temp_dir="$(mktemp -d)"
  original_root="${SHIPLOG_TEST_ROOT}"
  export SHIPLOG_TEST_ROOT="$temp_dir"

  run shiplog_snapshot_caller_repo_state
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "not a git repository"

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
  echo "$output" | grep -q "^$remote$"

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
  ! echo "$output" | grep -q "^$remote$"
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
  before="$(shiplog_git_caller config --get-all remote.${remote}.fetch | sort)"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote remove "$remote"
  shiplog_git_caller remote add "$remote" https://example.invalid/different.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after
  after="$(shiplog_git_caller config --get-all remote.${remote}.fetch | sort)"
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
  before="$(shiplog_git_caller config --get-all remote.${remote}.pushurl | sort)"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote remove "$remote"
  shiplog_git_caller remote add "$remote" https://example.invalid/wrong.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after
  after="$(shiplog_git_caller config --get-all remote.${remote}.pushurl | sort)"
  [ "$before" = "$after" ]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore handles remote with custom config keys" {
  local remote="shimtest-custom-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/custom.git
  shiplog_git_caller config "remote.${remote}.tagOpt" "--no-tags"
  shiplog_git_caller config "remote.${remote}.prune" "true"
  shiplog_git_caller config "remote.${remote}.skipDefaultUpdate" "true"

  local before
  before="$(shiplog_git_caller config --get-regexp "^remote\.${remote}\." | sort)"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote remove "$remote"
  shiplog_git_caller remote add "$remote" https://example.invalid/plain.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after
  after="$(shiplog_git_caller config --get-regexp "^remote\.${remote}\." | sort)"
  [ "$before" = "$after" ]

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
  echo "$output" | grep -q "^$remote2$"
  echo "$output" | grep -q "^$remote3$"

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q "^$remote2$"
  ! echo "$output" | grep -q "^$remote3$"
  echo "$output" | grep -q "^$remote1$"

  shiplog_git_caller remote remove "$remote1" >/dev/null 2>&1 || true
}

@test "restore is idempotent" {
  local remote="shimtest-idempotent-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/idempotent.git
  shiplog_git_caller config "remote.${remote}.fetch" "+refs/heads/*:refs/remotes/${remote}/*"

  local original
  original="$(shiplog_git_caller config --get-regexp "^remote\.${remote}\." | sort)"

  shiplog_snapshot_caller_repo_state

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after_first
  after_first="$(shiplog_git_caller config --get-regexp "^remote\.${remote}\." | sort)"
  [ "$original" = "$after_first" ]

  shiplog_git_caller config "remote.${remote}.tagOpt" "--tags"
  shiplog_snapshot_caller_repo_state
  shiplog_git_caller remote set-url "$remote" https://example.invalid/modified.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  run shiplog_git_caller config --get "remote.${remote}.tagOpt"
  [ "$status" -eq 0 ]
  [ "$output" = "--tags" ]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore handles remote with no URL configured" {
  local remote="shimtest-no-url-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/temp.git

  shiplog_git_caller config --unset-all "remote.${remote}.url" >/dev/null 2>&1 || true

  shiplog_snapshot_caller_repo_state
  [ "$?" -eq 0 ]

  shiplog_git_caller remote remove "$remote"

  run shiplog_restore_caller_remotes
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "Missing URL"
}

@test "git_caller executes commands in correct directory" {
  local remote="shimtest-gitcaller-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
  run shiplog_git_caller remote add "$remote" https://example.invalid/test.git
  [ "$status" -eq 0 ]

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "^$remote$"

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "git_caller respects safe.directory config" {
  run shiplog_git_caller status --short
  [ "$status" -eq 0 ]
}

@test "helper_error outputs to stderr" {
  run shiplog_helper_error "test error message"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "ERROR: test error message"
}

@test "helper_error formats multiple arguments" {
  run shiplog_helper_error "multiple" "args" "test"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "ERROR: multiple args test"
}

@test "restore skip flag triggers read-only handling" {
  export SHIPLOG_FORCE_REMOTE_RESTORE_SKIP=1
  shiplog_snapshot_caller_repo_state

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Skipping remote restore: config is read-only"

  unset SHIPLOG_FORCE_REMOTE_RESTORE_SKIP
}

@test "restore_exec returns success for valid commands" {
  local remote="shimtest-exec-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true

  run shiplog_restore_exec "test context" remote add "$remote" https://example.invalid/test.git
  [ "$status" -eq 0 ]

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "^$remote$"

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "restore_exec propagates command failures" {
  local remote="shimtest-fail-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/existing.git

  run shiplog_restore_exec "test context" remote add "$remote" https://example.invalid/duplicate.git
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "test context"

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "snapshot handles remotes with dots in name" {
  local remote="remote.with.dots-${BATS_TEST_NUMBER}"
  shiplog_reset_remote_snapshot_state
  shiplog_git_caller remote add "$remote" https://example.invalid/dots.git

  shiplog_snapshot_caller_repo_state
  [ "$?" -eq 0 ]
  [[ "${SHIPLOG_ORIG_REMOTES_CONFIG[$remote]}" == *"$remote.url"* ]]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}

@test "snapshot handles remotes with brackets in name" {
  local remote="remote[bracket]-${BATS_TEST_NUMBER}"
  shiplog_reset_remote_snapshot_state
  if shiplog_git_caller remote add "$remote" https://example.invalid/bracket.git 2>/dev/null; then
    shiplog_snapshot_caller_repo_state
    [ "$?" -eq 0 ]
    [[ "${SHIPLOG_ORIG_REMOTES_CONFIG[$remote]}" == *"url"* ]]
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

  local config_prod config_staging config_dev
  config_prod="$(shiplog_git_caller config --get-regexp "^remote\.${remote1}\." | sort)"
  config_staging="$(shiplog_git_caller config --get-regexp "^remote\.${remote2}\." | sort)"
  config_dev="$(shiplog_git_caller config --get-regexp "^remote\.${remote3}\." | sort)"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote remove "$remote1"
  shiplog_git_caller remote remove "$remote2"
  shiplog_git_caller remote remove "$remote3"
  shiplog_git_caller remote add "$remote1" https://example.invalid/wrong.git
  shiplog_git_caller remote add "$remote2" https://example.invalid/wrong.git
  shiplog_git_caller remote add extra-remote https://example.invalid/extra.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after_prod after_staging after_dev
  after_prod="$(shiplog_git_caller config --get-regexp "^remote\.${remote1}\." | sort)"
  after_staging="$(shiplog_git_caller config --get-regexp "^remote\.${remote2}\." | sort)"
  after_dev="$(shiplog_git_caller config --get-regexp "^remote\.${remote3}\." | sort)"

  [ "$config_prod" = "$after_prod" ]
  [ "$config_staging" = "$after_staging" ]
  [ "$config_dev" = "$after_dev" ]

  run shiplog_git_caller remote
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q "^extra-remote$"

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

  shiplog_restore_caller_remotes
  local rc=$?
  [ "$rc" -eq 0 ]
  [ "$SHIPLOG_CALLER_REPO_CAPTURED" -eq 0 ]

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
  echo "$output" | grep -q "^$remote1$"
  ! echo "$output" | grep -q "^$remote2$"

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
    echo "$output" | grep -qF "$remote"

    shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
  else
    skip "Git does not support this remote name format"
  fi
}

@test "restore maintains remote configuration after failed git operation" {
  local remote="shimtest-maintain-${BATS_TEST_NUMBER}"
  shiplog_git_caller remote add "$remote" https://example.invalid/test.git
  shiplog_git_caller config "remote.${remote}.important" "true"

  local before
  before="$(shiplog_git_caller config --get-regexp "^remote\.${remote}\." | sort)"

  shiplog_snapshot_caller_repo_state

  shiplog_git_caller remote set-url "$remote" https://example.invalid/changed.git

  run shiplog_restore_caller_remotes
  [ "$status" -eq 0 ]

  local after
  after="$(shiplog_git_caller config --get-regexp "^remote\.${remote}\." | sort)"
  [ "$before" = "$after" ]

  shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
}
