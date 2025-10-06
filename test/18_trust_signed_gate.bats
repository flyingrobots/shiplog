#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
}

teardown() {
  shiplog_standard_teardown
}

@test "unsigned trust push rejected when SHIPLOG_REQUIRE_SIGNED_TRUST=1" {
  # Create a bare remote and install the pre-receive hook with the gate set
  REMOTE_DIR=$(mktemp -d)
  git init -q --bare "$REMOTE_DIR"
  mkdir -p "$REMOTE_DIR/hooks"
  # Install a POSIX sh wrapper that execs bash for the real hook
  cp "$SHIPLOG_HOME/contrib/hooks/pre-receive.shiplog" "$REMOTE_DIR/hooks/pre-receive.real"
  printf '%s\n' '#!/bin/sh' 'export SHIPLOG_REQUIRE_SIGNED_TRUST=1' 'exec /bin/bash "$0.real" "$@"' > "$REMOTE_DIR/hooks/pre-receive"
  chmod +x "$REMOTE_DIR/hooks/pre-receive" "$REMOTE_DIR/hooks/pre-receive.real"
  git remote add origin "$REMOTE_DIR"

  # Bootstrap an unsigned trust commit (helpers create a default one)
  shiplog_bootstrap_trust 1

  run bash -lc 'git push -q origin refs/_shiplog/trust/root'
  [ "$status" -ne 0 ]
}

@test "signed trust push passes when SHIPLOG_REQUIRE_SIGNED_TRUST=1" {
  skip "SSH principal mapping varies across distros; enable once stabilized"
  # Fresh bare remote with pre-receive gate
  REMOTE_DIR=$(mktemp -d)
  git init -q --bare "$REMOTE_DIR"
  mkdir -p "$REMOTE_DIR/hooks"
  cp "$SHIPLOG_HOME/contrib/hooks/pre-receive.shiplog" "$REMOTE_DIR/hooks/pre-receive.real"
  printf '%s\n' '#!/bin/sh' 'export SHIPLOG_REQUIRE_SIGNED_TRUST=1' 'exec /bin/bash "$0.real" "$@"' > "$REMOTE_DIR/hooks/pre-receive"
  chmod +x "$REMOTE_DIR/hooks/pre-receive" "$REMOTE_DIR/hooks/pre-receive.real"
  git remote remove origin >/dev/null 2>&1 || true
  git remote add origin "$REMOTE_DIR"

  # Set up SSH signing and sign a new trust commit
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
  tree=$(printf "100644 blob %s\ttrust.json\n100644 blob %s\tallowed_signers\n" "$oid_trust" "$oid_sigs" | git mktree)
  commit=$(GIT_AUTHOR_NAME="Shiplog Tester" GIT_AUTHOR_EMAIL="shiplog-tester@example.com" \
    GIT_COMMITTER_NAME="Shiplog Tester" GIT_COMMITTER_EMAIL="shiplog-tester@example.com" \
    git commit-tree -S "$tree" -m "shiplog: trust root (signed)" )
  git update-ref refs/_shiplog/trust/root "$commit"

  run bash -lc 'git push -q origin refs/_shiplog/trust/root'
  echo "PUSH_OUT: $output"
  [ "$status" -eq 0 ]
}
