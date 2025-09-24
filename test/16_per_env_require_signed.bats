#!/usr/bin/env bats

load helpers/common

REMOTE_DIR=""
REMOTE_NAME="shiplog-test"

install_hook_remote() {
  local hook_source="${SHIPLOG_HOOK_PATH:-$SHIPLOG_PROJECT_ROOT/contrib/hooks/pre-receive.shiplog}"
  install -m 0755 "$hook_source" "$REMOTE_DIR/hooks/pre-receive"
}

setup() {
  shiplog_install_cli
  shiplog_use_sandbox_repo
  shiplog_bootstrap_trust
  # Policy: prod requires signed; staging unsigned
  mkdir -p .shiplog
  cat > .shiplog/policy.json <<'JSON'
{
  "version": 1,
  "require_signed": false,
  "authors": {"default_allowlist": ["shiplog-tester@example.com"]},
  "deployment_requirements": {
    "prod": { "require_signed": true },
    "staging": { "require_signed": false }
  }
}
JSON
  # Publish policy ref
  "$SHIPLOG_PROJECT_ROOT"/scripts/shiplog-sync-policy.sh >/dev/null

  export SHIPLOG_HOME="$SHIPLOG_PROJECT_ROOT"
  case ":$PATH:" in
    *":$SHIPLOG_PROJECT_ROOT/bin:"*) ;;
    *) export PATH="$SHIPLOG_PROJECT_ROOT/bin:$PATH" ;;
  esac
  git shiplog trust sync >/dev/null
  git config user.name "Shiplog Tester"
  git config user.email "shiplog-tester@example.com"
  export SHIPLOG_AUTO_PUSH=0

  REMOTE_DIR=$(mktemp -d)
  git init --bare "$REMOTE_DIR"
  install_hook_remote
  git remote remove "$REMOTE_NAME" >/dev/null 2>&1 || true
  git remote add "$REMOTE_NAME" "$REMOTE_DIR"
}

teardown() {
  git remote remove "$REMOTE_NAME" >/dev/null 2>&1 || true
  if [ -n "$REMOTE_DIR" ]; then
    rm -rf "$REMOTE_DIR"
  fi
  shiplog_cleanup_sandbox_repo
}

make_entry_unsigned() {
  local env="$1"
  SHIPLOG_SERVICE="svc" \
  SHIPLOG_STATUS="success" \
  SHIPLOG_REASON="per-env test" \
  SHIPLOG_TICKET="ENV-1" \
  SHIPLOG_REGION="us-east-1" \
  SHIPLOG_CLUSTER="prod-1" \
  SHIPLOG_NAMESPACE="default" \
  SHIPLOG_SIGN=0 \
  git shiplog --boring --yes write "$env" >/dev/null
}

@test "unsigned allowed in staging but rejected in prod" {
  git shiplog init >/dev/null
  # Push trust and policy
  git push -q "$REMOTE_NAME" refs/_shiplog/trust/root
  git push -q "$REMOTE_NAME" refs/_shiplog/policy/current

  # Staging unsigned should succeed
  make_entry_unsigned staging
  run git push "$REMOTE_NAME" refs/_shiplog/journal/staging
  [ "$status" -eq 0 ]

  # Prod unsigned should fail
  make_entry_unsigned prod
  run git push "$REMOTE_NAME" refs/_shiplog/journal/prod
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing required signature"* ]]
}

