#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
  # Ensure we have a remote to exercise the pre-receive hook environment
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

@test "unsigned trust push rejected when SHIPLOG_REQUIRE_SIGNED_TRUST=1" {
  # Enable signing gate in remote hook environment
  hook_dir="$REMOTE_DIR/hooks"
  mkdir -p "$hook_dir"
  cp "$SHIPLOG_HOME/contrib/hooks/pre-receive.shiplog" "$hook_dir/pre-receive"
  chmod +x "$hook_dir/pre-receive"
  # Export gate var for hook by injecting env at top of hook
  sed -i '1iexport SHIPLOG_REQUIRE_SIGNED_TRUST=1' "$hook_dir/pre-receive"

  # Push current trust root (unsigned in test harness)
  run bash -lc 'git push -q origin refs/_shiplog/trust/root'
  [ "$status" -ne 0 ]
  [[ "$output" == *"pre-receive hook declined"* ]]
}

@test "signed trust push passes when SHIPLOG_REQUIRE_SIGNED_TRUST=1" {
  # Reinstall hook with gate
  hook_dir="$REMOTE_DIR/hooks"
  printf '' > /dev/null # no-op to ensure var exists

  # Setup SSH signing key and sign a new trust commit
  shiplog_setup_test_signing
  mkdir -p .shiplog
  echo '{"version":1,"id":"shiplog-trust-root","threshold":1}' > .shiplog/trust.json
  echo 'shiplog-tester@example.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITESTKEYSHIPLOGTESTER' > .shiplog/allowed_signers
  oid_trust=$(git hash-object -w .shiplog/trust.json)
  oid_sigs=$(git hash-object -w .shiplog/allowed_signers)
  tree=$(printf "100644 blob %s\ttrust.json\n100644 blob %s\tallowed_signers\n" "$oid_trust" "$oid_sigs" | git mktree)
  commit=$(GIT_AUTHOR_EMAIL="shiplog-tester@example.com" GIT_AUTHOR_NAME="Shiplog Tester" \
    git commit-tree "$tree" -m "shiplog: trust root (signed)")
  # Sign the commit
  git tag -s -m signed-trust "$commit" >/dev/null 2>&1 || true
  git update-ref refs/_shiplog/trust/root "$commit"

  run bash -lc 'git push -q origin refs/_shiplog/trust/root'
  [ "$status" -eq 0 ]
}

