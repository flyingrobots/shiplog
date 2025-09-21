#!/usr/bin/env bats

# Verify required tools are available
command -v git >/dev/null 2>&1 || { echo "Error: git is required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Error: python3 is required for JSON validation" >&2; exit 1; }

load helpers/common

REMOTE_DIR=""
publish_policy() {
  local content="$1"
  [ -z "$content" ] && { echo "Error: content cannot be empty" >&2; return 1; }
  [ -d "$REMOTE_DIR" ] || { echo "Error: remote directory does not exist" >&2; return 1; }
  # Validate JSON content
  echo "$content" | python3 -m json.tool >/dev/null 2>&1 || { echo "Error: invalid JSON content" >&2; return 1; }
  local tmp
  tmp=$(mktemp) || { echo "Error: failed to create temp file" >&2; return 1; }
  trap 'rm -f "$tmp"' EXIT ERR
  printf '%s\n' "$content" > "$tmp"
  local blob tree shiplog_tree parent commit
  blob=$(git --git-dir="$REMOTE_DIR" hash-object -w "$tmp") || { echo "Error: failed to create blob" >&2; return 1; }
  shiplog_tree=$(printf '100644 blob %s\tpolicy.json\n' "$blob" | git --git-dir="$REMOTE_DIR" mktree) || { echo "Error: failed to create shiplog tree" >&2; return 1; }
  tree=$(printf '040000 tree %s\t.shiplog\n' "$shiplog_tree" | git --git-dir="$REMOTE_DIR" mktree) || { echo "Error: failed to create tree" >&2; return 1; }
  parent=$(git --git-dir="$REMOTE_DIR" rev-parse --verify refs/_shiplog/policy/current 2>/dev/null || true)
  if [ -n "$parent" ]; then
    commit=$(GIT_AUTHOR_NAME="Test Policy" GIT_AUTHOR_EMAIL="test-policy@shiplog.test" \
      GIT_COMMITTER_NAME="Test Policy" GIT_COMMITTER_EMAIL="test-policy@shiplog.test" \
      git --git-dir="$REMOTE_DIR" commit-tree "$tree" -p "$parent" -m "policy update")
    git --git-dir="$REMOTE_DIR" update-ref refs/_shiplog/policy/current "$commit" "$parent"
  else
    commit=$(GIT_AUTHOR_NAME="Test Policy" GIT_AUTHOR_EMAIL="test-policy@shiplog.test" \
      GIT_COMMITTER_NAME="Test Policy" GIT_COMMITTER_EMAIL="test-policy@shiplog.test" \
      git --git-dir="$REMOTE_DIR" commit-tree "$tree" -m "policy init")
    git --git-dir="$REMOTE_DIR" update-ref refs/_shiplog/policy/current "$commit"
  fi
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
  run git shiplog --boring write
  [ "$status" -eq 0 ]
}

setup() {
  shiplog_install_cli || { echo "Error: failed to install shiplog CLI" >&2; return 1; }
  export SHIPLOG_SIGN=0
  export SHIPLOG_ENV=prod
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
}

teardown() {
  git remote remove shiplog >/dev/null 2>&1 || true
  if [ -n "$REMOTE_DIR" ]; then
    rm -rf "$REMOTE_DIR" || echo "Warning: failed to remove $REMOTE_DIR" >&2
  fi
}

@test "pre-receive allows push for authorized author" {
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
