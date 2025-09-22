#!/usr/bin/env bats

load helpers/common

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}

count_exact_matches() {
  local needle="$1"
  local haystack="$2"
  printf '%s\n' "$haystack" | grep -F -x -c -- "$needle" || true
}

setup() {
  [ -d .git ] || { echo "Run inside docker test runner" >&2; exit 1; }
  shiplog_install_cli
  git config --unset-all remote.origin.fetch >/dev/null 2>&1 || true
  git config --add remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git config --unset-all remote.origin.push >/dev/null 2>&1 || true
}

@test "git shiplog init sets refspecs and reflogs" {
  run git shiplog init
  [ "$status" -eq 0 ]

  run git config --get-all remote.origin.fetch
  [ "$status" -eq 0 ]
  [[ "$output" == *"${REF_ROOT}/*:${REF_ROOT}/*"* ]]

  run git config --get core.logAllRefUpdates
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "git shiplog init is idempotent" {
  expected="+${REF_ROOT}/*:${REF_ROOT}/*"
  run git shiplog init
  [ "$status" -eq 0 ]
  run git shiplog init
  [ "$status" -eq 0 ]
  run git config --get-all remote.origin.fetch
  [ "$status" -eq 0 ]
  echo "$output" | grep -Fxc "$expected" | grep -q '^1$' || fail "expected exactly one fetch refspec matching '$expected'"

  run git config --get-all remote.origin.push
  [ "$status" -eq 0 ]
  head_count=$(count_exact_matches "HEAD" "$output")
  [ "$head_count" -eq 1 ] || fail "expected single HEAD push refspec, got $head_count"
  push_count=$(count_exact_matches "${REF_ROOT}/*:${REF_ROOT}/*" "$output")
  [ "$push_count" -eq 1 ] || fail "expected single shiplog push refspec, got $push_count"
}

@test "git shiplog init preserves custom push specs" {
  git config remote.origin.push 'refs/heads/*:refs/remotes/origin/*'
  run git shiplog init
  [ "$status" -eq 0 ]

  run git config --get-all remote.origin.push
  [ "$status" -eq 0 ]
  [[ "$output" == *"refs/heads/*:refs/remotes/origin/*"* ]] || fail "missing existing push refspec"
  shiplog_count=$(count_exact_matches "${REF_ROOT}/*:${REF_ROOT}/*" "$output")
  [ "$shiplog_count" -eq 1 ] || fail "expected single shiplog push refspec"
  head_present=$(printf '%s\n' "$output" | grep -Fxc "HEAD" || true)
  [ "$head_present" -eq 0 ] || fail "HEAD refspec should not be added when custom pushes exist"
}

@test "ls on empty journal errors cleanly" {
  run git shiplog ls
  [ "$status" -ne 0 ]
  [[ "$output" == *"No entries at"* ]]
}
