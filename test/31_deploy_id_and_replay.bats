#!/usr/bin/env bats

load helpers/common

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_AUTO_PUSH=0
}

teardown() {
  shiplog_standard_teardown
  unset SHIPLOG_AUTO_PUSH
}

@test "run --deployment stamps deployment.id and mirrors ticket when empty" {
  run bash -lc 'git shiplog run --deployment DEP-123 --service test -- true'
  [ "$status" -eq 0 ]
  sha=$(git rev-parse "${REF_ROOT}/journal/prod")
  run bash -lc "git shiplog show --json $sha | jq -e '.deployment.id==\"DEP-123\" and .why.ticket==\"DEP-123\"'"
  [ "$status" -eq 0 ]
}

@test "append --deployment adds deployment.id and keeps explicit ticket" {
  run bash -lc 'git shiplog append --env prod --service test --ticket T-1 --deployment DEP-999 --json "{}"'
  [ "$status" -eq 0 ]
  sha=$(git rev-parse "${REF_ROOT}/journal/prod")
  run bash -lc "git shiplog show --json $sha | jq -e '.deployment.id==\"DEP-999\" and .why.ticket==\"T-1\"'"
  [ "$status" -eq 0 ]
}

@test "replay --deployment filters entries by id" {
  run bash -lc '
    eval "$(scripts/shiplog-deploy-id.sh --export)" && id="$SHIPLOG_DEPLOY_ID" && \
    git shiplog run --service test -- true && \
    other=$(scripts/shiplog-deploy-id.sh) && SHIPLOG_DEPLOY_ID="$other" git shiplog run --service test -- true && \
    scripts/shiplog-replay.sh --env prod --deployment "$id" --count 100 --speed 0 > out.txt && \
    grep -c "▶" out.txt
  '
  [ "$status" -eq 0 ]
  # Expect at least 1 entry and not both
  [ "$output" -eq 1 ]
}

