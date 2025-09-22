#!/usr/bin/env bats

load helpers/common

REMOTE_DIR=""
publish_policy() {
  local content="$1"
  [ -z "$content" ] && { echo "Error: content cannot be empty" >&2; return 1; }
  [ -d "$REMOTE_DIR" ] || { echo "Error: remote directory does not exist" >&2; return 1; }
  # Validate JSON content
  echo "$content" | jq -e '.' >/dev/null 2>&1 || { echo "Error: invalid JSON content" >&2; return 1; }
  local tmp
  tmp=$(mktemp) || { echo "Error: failed to create temp file" >&2; return 1; }
  printf '%s\n' "$content" > "$tmp"
  local blob tree shiplog_tree parent commit
  blob=$(git --git-dir="$REMOTE_DIR" hash-object -w "$tmp") || { echo "Error: failed to create blob" >&2; rm -f "$tmp"; return 1; }
  shiplog_tree=$(printf '100644 blob %s\tpolicy.json\n' "$blob" | git --git-dir="$REMOTE_DIR" mktree) || { echo "Error: failed to create shiplog tree" >&2; rm -f "$tmp"; return 1; }
  tree=$(printf '040000 tree %s\t.shiplog\n' "$shiplog_tree" | git --git-dir="$REMOTE_DIR" mktree) || { echo "Error: failed to create tree" >&2; rm -f "$tmp"; return 1; }
  parent=$(git --git-dir="$REMOTE_DIR" rev-parse --verify refs/_shiplog/policy/current 2>/dev/null || true)
  if [ -n "$parent" ]; then
    commit=$(GIT_AUTHOR_NAME="Test Policy" GIT_AUTHOR_EMAIL="test-policy@shiplog.test" \
      GIT_COMMITTER_NAME="Test Policy" GIT_COMMITTER_EMAIL="test-policy@shiplog.test" \
      git --git-dir="$REMOTE_DIR" commit-tree "$tree" -p "$parent" -m "policy update")
    git --git-dir="$REMOTE_DIR" update-ref refs/_shiplog/policy/current "$commit" "$parent" || { rm -f "$tmp"; return 1; }
  else
    commit=$(GIT_AUTHOR_NAME="Test Policy" GIT_AUTHOR_EMAIL="test-policy@shiplog.test" \
      GIT_COMMITTER_NAME="Test Policy" GIT_COMMITTER_EMAIL="test-policy@shiplog.test" \
      git --git-dir="$REMOTE_DIR" commit-tree "$tree" -m "policy init") || { rm -f "$tmp"; return 1; }
    git --git-dir="$REMOTE_DIR" update-ref refs/_shiplog/policy/current "$commit" || { rm -f "$tmp"; return 1; }
  fi
  rm -f "$tmp"
}

make_entry() {
  local service=${1:-hook-test}
  local status=${2:-success}
  local reason=${3:-"policy exercise"}
  local ticket=${4:-HOOK-1}
  local region=${5:-us-west-2}
  local cluster=${6:-prod-1}
  local namespace=${7:-default}
  local image=${8:-ghcr.io/example/app}
  local tag=${9:-v0.0.1}

  # --boring keeps the command non-interactive so tests never block waiting for input.
  SHIPLOG_SERVICE="$service" \
  SHIPLOG_STATUS="$status" \
  SHIPLOG_REASON="$reason" \
  SHIPLOG_TICKET="$ticket" \
  SHIPLOG_REGION="$region" \
  SHIPLOG_CLUSTER="$cluster" \
  SHIPLOG_NAMESPACE="$namespace" \
  SHIPLOG_IMAGE="$image" \
  SHIPLOG_TAG="$tag" \
  run git shiplog --boring --yes write
  if [ "$status" -ne 0 ]; then
    echo "make_entry output: $output" >&2
  fi
  [ "$status" -eq 0 ]
}

setup() {
  shiplog_install_cli || { echo "Error: failed to install shiplog CLI" >&2; return 1; }
  export SHIPLOG_SIGN=0
  export SHIPLOG_ENV=prod
  export SHIPLOG_AUTO_PUSH=0
  git config user.name "Shiplog Test" || { echo "Error: failed to set git user.name" >&2; return 1; }
  git config user.email "shiplog-test@example.local" || { echo "Error: failed to set git user.email" >&2; return 1; }
  [ -f .shiplog/policy.json ] && rm -f .shiplog/policy.json
  git config --unset-all shiplog.policy.allowedAuthors >/dev/null 2>&1 || true
  git config --unset-all shiplog.policy.requireSigned >/dev/null 2>&1 || true
  git update-ref -d refs/_shiplog/journal/prod >/dev/null 2>&1 || true
  git update-ref -d refs/_shiplog/journal/stage >/dev/null 2>&1 || true
  git update-ref -d refs/_shiplog/anchors/prod >/dev/null 2>&1 || true
  git update-ref -d refs/_shiplog/anchors/stage >/dev/null 2>&1 || true
  REMOTE_DIR=$(mktemp -d) || { echo "Error: failed to create temp directory" >&2; return 1; }
  git init --bare "$REMOTE_DIR" || { echo "Error: failed to init bare repo" >&2; return 1; }
  
  # Allow override via environment variable for portability
  local hook_source="${SHIPLOG_HOOK_PATH:-/workspace/contrib/hooks/pre-receive.shiplog}"
  [ -f "$hook_source" ] || { echo "Error: pre-receive hook not found at $hook_source" >&2; return 1; }
  install -m 0755 "$hook_source" "$REMOTE_DIR/hooks/pre-receive" || { echo "Error: failed to install hook" >&2; return 1; }
  git remote remove shiplog >/dev/null 2>&1 || true
  git remote add shiplog "$REMOTE_DIR" || { echo "Error: failed to add remote" >&2; return 1; }
  git shiplog --boring init >/dev/null || { echo "Error: failed to run git shiplog init" >&2; return 1; }
}

teardown() {
  git remote remove shiplog >/dev/null 2>&1 || true
  if [ -n "$REMOTE_DIR" ]; then
    rm -rf "$REMOTE_DIR" || echo "Warning: failed to remove $REMOTE_DIR" >&2
  fi
}

@test "pre-receive allows push for authorized author" {
  skip "pre-receive hook integration pending"
  publish_policy "$(cat <<'POL'
{
  "version": 1,
  "require_signed": false,
  "authors": {
    "default_allowlist": [
      "shiplog-test@example.local"
    ]
  }
}
POL
)"
  make_entry
  run git push shiplog refs/_shiplog/journal/prod
  [ "$status" -eq 0 ]
  # Verify the push actually worked
  run git --git-dir="$REMOTE_DIR" rev-parse refs/_shiplog/journal/prod
  [ "$status" -eq 0 ]
  # Verify output is a valid Git SHA (40 hex characters)
  [[ "$output" =~ ^[a-f0-9]{40}$ ]]
}

@test "pre-receive rejects unauthorized author" {
  skip "pre-receive hook integration pending"
  publish_policy "$(cat <<'POL'
{
  "version": 1,
  "require_signed": false,
  "authors": {
    "default_allowlist": [
      "someoneelse@example.com"
    ]
  }
}
POL
)"
  make_entry
  run git push shiplog refs/_shiplog/journal/prod
  [ "$status" -ne 0 ]
  # Be more specific about what we're checking
  # Check for specific authorization failure message from the hook
  [[ "$output" == *"shiplog-test@example.local"*"not"*"allowed"* ]] || \
  [[ "$output" == *"unauthorized author"* ]] || \
  [[ "$output" == *"author not in allowlist"* ]]
  # Verify the ref was NOT created
  run git --git-dir="$REMOTE_DIR" rev-parse refs/_shiplog/journal/prod
  [ "$status" -ne 0 ]
}

@test "pre-receive enforces signatures when required" {
  skip "pre-receive hook integration pending"
  publish_policy "$(cat <<'POL'
{
  "version": 1,
  "require_signed": true,
  "authors": {
    "default_allowlist": [
      "shiplog-test@example.local"
    ]
  }
}
POL
)"
  make_entry
  run git push shiplog refs/_shiplog/journal/prod
  [ "$status" -ne 0 ]
  # Check for specific signature requirement failure from the hook
  [[ "$output" == *"commit signature required"* ]] || \
  [[ "$output" == *"signed commit required"* ]] || \
  [[ "$output" == *"missing required signature"* ]]
  # Verify the ref was NOT created due to signature issue
  run git --git-dir="$REMOTE_DIR" rev-parse refs/_shiplog/journal/prod
  [ "$status" -ne 0 ]
}
