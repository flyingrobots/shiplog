#!/usr/bin/env bats

@test "installer sets up dependencies in clean container" {
  if ! command -v docker >/dev/null 2>&1; then
    skip "docker CLI not available"
  fi
}
 
@test "installer installs dependencies in clean container" {
  if ! command -v docker >/dev/null 2>&1; then
    skip "docker CLI not available"
  fi
  run docker run --rm -v "$PWD":/workspace debian:bookworm-slim bash -c '
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update >/dev/null && apt-get install -y git curl ca-certificates >/dev/null
    cd /workspace && ./install-shiplog-deps.sh --silent
    gum --version && jq --version
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ "gum" ]] || { echo "Missing gum verification in output"; return 1; }
  [[ "$output" =~ "jq" ]] || { echo "Missing jq verification in output"; return 1; }
}
 
@test "git-shiplog binary works in clean container" {
  if ! command -v docker >/dev/null 2>&1; then
    skip "docker CLI not available"
  fi
  run docker run --rm -v "$PWD":/workspace debian:bookworm-slim bash -c '
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update >/dev/null && apt-get install -y git curl ca-certificates >/dev/null
    cd /workspace
    ./install-shiplog-deps.sh --silent
    install -m 0755 /workspace/bin/git-shiplog /usr/local/bin/git-shiplog
    mkdir smoke && cd smoke
    git init -q
    git config user.name Smoke && git config user.email smoke@example.com
    git commit --allow-empty -m init >/dev/null
    SHIPLOG_HOME=/workspace git shiplog --boring init >/dev/null
  '
  [ "$status" -eq 0 ]
}
