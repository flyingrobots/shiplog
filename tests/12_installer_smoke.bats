#!/usr/bin/env bats

@test "installer sets up dependencies in clean container" {
  if ! command -v docker >/dev/null 2>&1; then
    skip "docker CLI not available"
  fi
  run docker run --rm -v "$PWD":/workspace debian:bookworm-slim bash -lc '
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update >/dev/null
    apt-get install -y git curl ca-certificates >/dev/null
    cd /workspace
    ./install-shiplog-deps.sh --silent
    gum --version >/dev/null
    jq --version >/dev/null
    yq --version >/dev/null
    mkdir smoke && cd smoke
    git init -q
    git config user.name Smoke
    git config user.email smoke@example.com
    git commit --allow-empty -m init >/dev/null
    SHIPLOG_HOME=/workspace /workspace/bin/shiplog --boring init >/dev/null
    echo OK
  '
  [ "$status" -eq 0 ]
  [[ "${lines[-1]}" == "SUCCESS" ]]
}
