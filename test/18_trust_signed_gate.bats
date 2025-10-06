#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
  # Prepare a bare remote for exercising the pre-receive hook
  REMOTE_DIR=$(mktemp -d)
  pushd "$REMOTE_DIR" >/dev/null
  git init -q --bare
  popd >/dev/null
  git remote add origin "$REMOTE_DIR"
}

teardown() {
  rm -rf "$REMOTE_DIR" 2>/dev/null || true
  shiplog_standard_teardown
}

install_hook_with_gate() {
  mkdir -p "$REMOTE_DIR/hooks"
  # Wrap to ensure bash execution under sh-only environments
  cp "$SHIPLOG_HOME/contrib/hooks/pre-receive.shiplog" "$REMOTE_DIR/hooks/pre-receive.real"
  printf '%s\n' '#!/bin/bash' 'export SHIPLOG_REQUIRE_SIGNED_TRUST=1' 'exec /bin/bash "$0.real" "$@"' > "$REMOTE_DIR/hooks/pre-receive"
  chmod +x "$REMOTE_DIR/hooks/pre-receive" "$REMOTE_DIR/hooks/pre-receive.real"
}

@test "unsigned trust push rejected when SHIPLOG_REQUIRE_SIGNED_TRUST=1" {
  install_hook_with_gate

  # Bootstrap an unsigned trust commit (helpers create a default one)
  shiplog_bootstrap_trust 1

  run git push -q origin refs/_shiplog/trust/root
  [ "$status" -ne 0 ]
  [[ "$output" == *"pre-receive hook declined"* ]]
}

@test "signed trust push passes when SHIPLOG_REQUIRE_SIGNED_TRUST=1" {
  skip "SSH principal mapping varies across distros; enable once stabilized"
  install_hook_with_gate

  # Set up SSH signing and sign a new trust commit (commit signature, not tag)
  shiplog_setup_test_signing
  git config user.email "shiplog-tester@example.com"
  mkdir -p .shiplog
  cat > .shiplog/trust.json <<'JSON'
{
  "version": 1,
  "id": "shiplog-trust-root",
  "threshold": 1,
  "maintainers": [ {"name":"Shiplog Tester","email":"shiplog-tester@example.com","role":"root","revoked":false} ]
}
JSON
  # Build allowed_signers from the configured SSH signing key
  priv="$(git config user.signingkey)"
  pub="$(ssh-keygen -y -f "$priv")"
  printf '* %s\n' "$pub" > .shiplog/allowed_signers
  oid_trust=$(git hash-object -w .shiplog/trust.json)
  oid_sigs=$(git hash-object -w .shiplog/allowed_signers)
  tab=$'\t'
  tree=$(printf "100644 blob %s${tab}trust.json\n100644 blob %s${tab}allowed_signers\n" "$oid_trust" "$oid_sigs" | git mktree)
  commit=$(GIT_AUTHOR_NAME="Shiplog Tester" GIT_AUTHOR_EMAIL="shiplog-tester@example.com" \
    GIT_COMMITTER_NAME="Shiplog Tester" GIT_COMMITTER_EMAIL="shiplog-tester@example.com" \
    git commit-tree -S "$tree" -m "shiplog: trust root (signed)" )
  git update-ref refs/_shiplog/trust/root "$commit"

  run git push -q origin refs/_shiplog/trust/root
  [ "$status" -eq 0 ]
}
