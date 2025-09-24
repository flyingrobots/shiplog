#!/usr/bin/env bats

load helpers/common

REMOTE_DIR=""
REMOTE_NAME="shiplog-test"

install_hook_remote() {
  local hook_source="${SHIPLOG_HOOK_PATH:-$SHIPLOG_PROJECT_ROOT/contrib/hooks/pre-receive.shiplog}"
  install -m 0755 "$hook_source" "$REMOTE_DIR/hooks/pre-receive"
}

push_trust_ref_only_trust_json() {
  # Create trust commit without allowed_signers to exercise hook validation
  mkdir -p .shiplog
  cat > .shiplog/trust.json <<'JSON'
{
  "version": 1,
  "id": "shiplog-trust-root",
  "threshold": 1,
  "maintainers": [
    {"name": "T", "email": "t@example.com", "pgp_fpr": null, "role": "root", "revoked": false}
  ]
}
JSON
  local trust_blob tree commit
  trust_blob=$(git hash-object -w .shiplog/trust.json)
  tree=$(printf '100644 blob %s\ttrust.json\n' "$trust_blob" | git mktree)
  commit=$(GIT_AUTHOR_NAME="Trust Init" GIT_AUTHOR_EMAIL="trust@shiplog.test" \
    GIT_COMMITTER_NAME="Trust Init" GIT_COMMITTER_EMAIL="trust@shiplog.test" \
    git commit-tree "$tree" -m "shiplog: trust root v1 (GENESIS)")
  git update-ref refs/_shiplog/trust/root "$commit"
  git push -q "$REMOTE_NAME" refs/_shiplog/trust/root
}

make_entry_unsigned() {
  SHIPLOG_SERVICE="signing-test" \
  SHIPLOG_STATUS="success" \
  SHIPLOG_REASON="unsigned entry" \
  SHIPLOG_TICKET="SIGN-1" \
  SHIPLOG_REGION="us-east-1" \
  SHIPLOG_CLUSTER="prod-1" \
  SHIPLOG_NAMESPACE="default" \
  SHIPLOG_IMAGE="ghcr.io/example/app" \
  SHIPLOG_TAG="v0.0.1" \
  SHIPLOG_RUN_URL="https://ci.example.local/run/456" \
  SHIPLOG_SIGN=0 \
  git shiplog --boring --yes write >/dev/null
}

setup() {
  shiplog_install_cli
  shiplog_use_sandbox_repo
  shiplog_bootstrap_trust
  shiplog_bootstrap_policy_ref
  # Enforce signatures for this test file
  cat > .shiplog/policy.json <<'JSON'
{
  "version": 1,
  "require_signed": true,
  "authors": {"default_allowlist": ["shiplog-tester@example.com"]}
}
JSON
  export SHIPLOG_HOME="$SHIPLOG_PROJECT_ROOT"
  case ":$PATH:" in
    *":$SHIPLOG_PROJECT_ROOT/bin:"*) ;;
    *) export PATH="$SHIPLOG_PROJECT_ROOT/bin:$PATH" ;;
  esac
  git shiplog trust sync >/dev/null
  git config user.name "Shiplog Tester"
  git config user.email "shiplog-tester@example.com"

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

@test "rejects trust update without allowed_signers" {
  run push_trust_ref_only_trust_json
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing allowed_signers"* ]]
}

@test "rejects unsigned journal when require_signed=true" {
  # Push valid trust and policy first
  git push -q "$REMOTE_NAME" refs/_shiplog/trust/root
  git push -q "$REMOTE_NAME" refs/_shiplog/policy/current
  git shiplog init >/dev/null
  make_entry_unsigned
  run git push "$REMOTE_NAME" refs/_shiplog/journal/prod
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing required signature"* ]]
}

@test "(skipped) server does not trust client-side allowed_signers" {
  if [ "${ENABLE_SIGNING:-false}" != "true" ]; then
    skip "Signing support not enabled in this build"
  fi
  skip "Loopback signing test requires reliable signing in CI"
}

