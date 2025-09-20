#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_install_cli
  export SHIPLOG_SIGN=0
  export SHIPLOG_ENV="prod"
}

@test "--boring write consumes SHIPLOG_* defaults" {
  export SHIPLOG_SERVICE="boring-web"
  export SHIPLOG_STATUS="success"
  export SHIPLOG_REASON="non-interactive deploy"
  export SHIPLOG_TICKET="BORING-1"
  export SHIPLOG_REGION="us-east-1"
  export SHIPLOG_CLUSTER="prod-a"
  export SHIPLOG_NAMESPACE="default"
  export SHIPLOG_IMAGE="ghcr.io/example/boring"
  export SHIPLOG_TAG="v1.2.3"
  run shiplog --boring write
  [ "$status" -eq 0 ]

  run git show -s --format=%s refs/_shiplog/journal/prod
  [ "$status" -eq 0 ]
  [[ "$output" == "Deploy: boring-web"* ]]
}
