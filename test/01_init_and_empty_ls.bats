#!/usr/bin/env bats

load helpers/common

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}

setup() {
  [ -d .git ] || { echo "Run inside docker test runner" >&2; exit 1; }
  shiplog_install_cli
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
  fetch_count=$(printf '%s\n' "$output" | grep -Fx "$expected" | wc -l | tr -d '[:space:]')
  [ "$fetch_count" -eq 1 ] || fail "expected single fetch refspec, got $fetch_count"

  run git config --get-all remote.origin.push
  [ "$status" -eq 0 ]
  head_count=$(printf '%s\n' "$output" | grep -Fx "HEAD" | wc -l | tr -d '[:space:]')
  [ "$head_count" -eq 1 ] || fail "expected single HEAD push refspec, got $head_count"
  push_count=$(printf '%s\n' "$output" | grep -Fx "${REF_ROOT}/*:${REF_ROOT}/*" | wc -l | tr -d '[:space:]')
  [ "$push_count" -eq 1 ] || fail "expected single shiplog push refspec, got $push_count"
}

@test "ls on empty journal errors cleanly" {
  run git shiplog ls
  [ "$status" -ne 0 ]
  [[ "$output" == *"No entries at"* ]]
}
