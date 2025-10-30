#!/usr/bin/env bats

load helpers/common

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_SIGN=0
  export SHIPLOG_AUTO_PUSH=0
}

teardown() {
  shiplog_standard_teardown
  unset SHIPLOG_SIGN SHIPLOG_AUTO_PUSH
}

@test "run --preamble streams output and prints start/end glyphs (success)" {
  run bash -lc 'git shiplog run --preamble --service test -- env printf hi'
  [ "$status" -eq 0 ]
  [[ "$output" == *"🚢🪵🎬"* ]]
  [[ "$output" == *" |  hi"* ]]
  [[ "$output" == *"🚢🪵✅"* ]]
}

@test "run --preamble prints failure end glyph and returns non-zero" {
  run bash -lc 'git shiplog run --preamble --service test -- /bin/false'
  [ "$status" -ne 0 ]
  [[ "$output" == *"🚢🪵🎬"* ]]
  [[ "$output" == *"🚢🪵❌"* ]]
}

@test "run exit code matches trailer run.exit_code (success)" {
  run bash -lc 'git shiplog run --service test -- true'
  [ "$status" -eq 0 ]
  sha=$(git rev-parse "${REF_ROOT}/journal/prod")
  run bash -lc "git shiplog show --json $sha | jq -e '.run.exit_code == 0'"
  [ "$status" -eq 0 ]
}

@test "run with no output records log_attached=false" {
  run bash -lc 'git shiplog run --service test -- true'
  [ "$status" -eq 0 ]
  sha=$(git rev-parse "${REF_ROOT}/journal/prod")
  run bash -lc "git shiplog show --json $sha | jq -r '.run.log_attached'"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "run warns on literal command substitution token in argv" {
  run bash -lc 'git shiplog run --service test -- echo "\$()"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"detected possible command substitution token"* ]]
  [[ "$output" == *"$()"* ]]
}

@test "run --no-preamble suppresses preamble glyphs and prefix" {
  run bash -lc 'git shiplog run --no-preamble --service test -- env printf hi'
  [ "$status" -eq 0 ]
  [[ "$output" == *"hi"* ]]
  [[ "$output" != *"🚢🪵🎬"* ]]
  [[ "$output" != *"🚢🪵✅"* ]]
  [[ "$output" != *" |  hi"* ]]
}

@test "run in boring mode prints only confirmation (no streaming) and still attaches log" {
  run bash -lc 'SHIPLOG_BORING=1 git shiplog run --service test -- env printf hi'
  [ "$status" -eq 0 ]
  # No streaming/preamble in boring mode, but a minimal confirmation glyph prints
  [[ "$output" == *"🪵"* ]]
  [[ "$output" != *" |  "* ]]
  [[ "$output" != *"🚢🪵🎬"* ]]
  sha=$(git rev-parse "${REF_ROOT}/journal/prod")
  run bash -lc "git shiplog show --json $sha | jq -r '.run.log_attached'"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}
