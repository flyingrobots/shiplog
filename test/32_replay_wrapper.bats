#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  export SHIPLOG_AUTO_PUSH=0
}

teardown() {
  shiplog_standard_teardown
  unset SHIPLOG_AUTO_PUSH
}

@test "replay wrapper runs via --deployment" {
  run bash -lc '
    eval "$(scripts/shiplog-deploy-id.sh --export)"
    git shiplog run --deployment "$SHIPLOG_DEPLOY_ID" --service test -- bash -lc "printf A"
    git shiplog replay --deployment "$SHIPLOG_DEPLOY_ID" --env prod --count 50 --speed 0
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"▶"* ]]
  [[ "$output" == *"A"* ]]
}

@test "replay --since-anchor resolves start boundary" {
  run bash -lc '
    git shiplog anchor set --env prod --reason start >/dev/null || true
    git shiplog run --service test -- bash -lc "printf B"
    git shiplog replay --env prod --since-anchor --count 50 --speed 0
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"B"* ]]
}

@test "replay --pointer uses reflog window when available" {
  run bash -lc '
    ref="refs/_shiplog/deploy/prod"
    git update-ref -m "start deployment" "$ref" "$(git rev-parse refs/_shiplog/journal/prod)"
    git shiplog run --service test -- bash -lc "printf C"
    git update-ref -m "end deployment" "$ref" "$(git rev-parse refs/_shiplog/journal/prod)"
    git shiplog replay --pointer "$ref" --env prod --speed 0
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"C"* ]]
}

