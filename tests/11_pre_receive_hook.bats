#!/usr/bin/env bats

load helpers/common

REMOTE_DIR=""

publish_policy() {
  local content="$1"
  local tmp
  tmp=$(mktemp)
  printf '%s\n' "$content" > "$tmp"
  local blob tree shiplog_tree parent commit
  blob=$(git --git-dir="$REMOTE_DIR" hash-object -w "$tmp")
  shiplog_tree=$(printf '100644 blob %s\tpolicy.yaml\n' "$blob" | git --git-dir="$REMOTE_DIR" mktree)
  tree=$(printf '040000 tree %s\t.shiplog\n' "$shiplog_tree" | git --git-dir="$REMOTE_DIR" mktree)
  parent=$(git --git-dir="$REMOTE_DIR" rev-parse --verify refs/_shiplog/policy/current 2>/dev/null || echo "")
  if [ -n "$parent" ]; then
    commit=$(GIT_AUTHOR_NAME="Policy" GIT_AUTHOR_EMAIL="policy@example.com" \
      GIT_COMMITTER_NAME="Policy" GIT_COMMITTER_EMAIL="policy@example.com" \
      git --git-dir="$REMOTE_DIR" commit-tree "$tree" -p "$parent" -m "policy update")
    git --git-dir="$REMOTE_DIR" update-ref refs/_shiplog/policy/current "$commit" "$parent"
  else
    commit=$(GIT_AUTHOR_NAME="Policy" GIT_AUTHOR_EMAIL="policy@example.com" \
      GIT_COMMITTER_NAME="Policy" GIT_COMMITTER_EMAIL="policy@example.com" \
      git --git-dir="$REMOTE_DIR" commit-tree "$tree" -m "policy init")
    git --git-dir="$REMOTE_DIR" update-ref refs/_shiplog/policy/current "$commit"
  fi
  rm -f "$tmp"
}

make_entry() {
  export SHIPLOG_SERVICE=${1:-hook-test}
  export SHIPLOG_STATUS=${2:-success}
  export SHIPLOG_REASON=${3:-"policy exercise"}
  export SHIPLOG_TICKET=${4:-HOOK-1}
  export SHIPLOG_REGION=${5:-us-west-2}
  export SHIPLOG_CLUSTER=${6:-prod-1}
  export SHIPLOG_NAMESPACE=${7:-default}
  export SHIPLOG_IMAGE=${8:-ghcr.io/example/app}
  export SHIPLOG_TAG=${9:-v0.0.1}
  run shiplog --boring write
  [ "$status" -eq 0 ]
}

setup() {
  shiplog_install_cli
  export SHIPLOG_SIGN=0
  export SHIPLOG_ENV=prod
  git config user.name "Shiplog Test"
  git config user.email "shiplog-test@example.local"
  rm -f .shiplog/policy.yaml
  git config --unset-all shiplog.policy.allowedAuthors >/dev/null 2>&1 || true
  git config --unset-all shiplog.policy.requireSigned >/dev/null 2>&1 || true
  git update-ref -d refs/_shiplog/journal/prod >/dev/null 2>&1 || true
  git update-ref -d refs/_shiplog/journal/stage >/dev/null 2>&1 || true
  git update-ref -d refs/_shiplog/anchors/prod >/dev/null 2>&1 || true
  git update-ref -d refs/_shiplog/anchors/stage >/dev/null 2>&1 || true
  REMOTE_DIR=$(mktemp -d)
  git init --bare "$REMOTE_DIR"
  install -m 0755 /workspace/contrib/hooks/pre-receive.shiplog "$REMOTE_DIR/hooks/pre-receive"
  git remote remove shiplog >/dev/null 2>&1 || true
  git remote add shiplog "$REMOTE_DIR"
}

teardown() {
  git remote remove shiplog >/dev/null 2>&1 || true
  [ -n "$REMOTE_DIR" ] && rm -rf "$REMOTE_DIR"
}

@test "pre-receive allows push for authorized author" {
  publish_policy "$(cat <<'POL'
version: 1
require_signed: false
authors:
  default_allowlist:
    - shiplog-test@example.local
POL
)"
  make_entry
  run git push shiplog refs/_shiplog/journal/prod
  [ "$status" -eq 0 ]
}

@test "pre-receive rejects unauthorized author" {
  publish_policy "$(cat <<'POL'
version: 1
require_signed: false
authors:
  default_allowlist:
    - someoneelse@example.com
POL
)"
  make_entry
  run bash -lc 'git push shiplog refs/_shiplog/journal/prod 2>&1'
  [ "$status" -ne 0 ]
  [[ "$output" == *"not allowed"* ]]
}

@test "pre-receive enforces signatures when required" {
  publish_policy "$(cat <<'POL'
version: 1
require_signed: true
authors:
  default_allowlist:
    - shiplog-test@example.local
POL
)"
  make_entry
  run bash -lc 'git push shiplog refs/_shiplog/journal/prod 2>&1'
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing signature"* ]]
}
