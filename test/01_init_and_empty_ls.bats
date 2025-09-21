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

@test "ls on empty journal errors cleanly" {
  run git shiplog ls
  [ "$status" -ne 0 ]
  [[ "$output" == *"No entries at"* ]]
}
