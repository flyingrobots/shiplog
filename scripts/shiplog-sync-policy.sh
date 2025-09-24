#!/usr/bin/env bash
set -euo pipefail

POLICY_FILE=${1:-.shiplog/policy.json}
POLICY_REF=${SHIPLOG_POLICY_REF:-refs/_shiplog/policy/current}
MESSAGE=${SHIPLOG_POLICY_MESSAGE:-"shiplog: update policy"}
SIGN_MODE=${SHIPLOG_POLICY_SIGN:-0}
SCHEMA_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../examples/policy.schema.json"

if [ ! -f "$POLICY_FILE" ]; then
  echo "shiplog: policy file $POLICY_FILE not found" >&2
  exit 1
fi

if [ -f "$SCHEMA_PATH" ] && command -v jq >/dev/null 2>&1 && jq --help 2>&1 | grep -q -- '--schema'; then
  if ! jq --schema "$SCHEMA_PATH" '.' "$POLICY_FILE" >/dev/null 2>&1; then
    echo "shiplog: policy file $POLICY_FILE failed schema validation" >&2
    exit 1
  fi
else
  echo "shiplog: schema validation skipped (jq --schema unavailable or schema missing)" >&2
fi

blob=$(git hash-object -w "$POLICY_FILE")
entry=$(printf '100644 blob %s\t%s\n' "$blob" "$(basename "$POLICY_FILE")")
tree=$(printf "%s" "$entry" | git mktree)
parent=$(git rev-parse -q --verify "$POLICY_REF" 2>/dev/null || echo "")

commit_args=("$tree")
if [ -n "$parent" ]; then
  commit_args+=( -p "$parent" )
fi

if [ "$SIGN_MODE" = "0" ]; then
  commit=$(printf '%s\n' "$MESSAGE" | GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$(git config user.name)}" GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$(git config user.email)}" git commit-tree "${commit_args[@]}")
else
  commit=$(printf '%s\n' "$MESSAGE" | git commit-tree "${commit_args[@]}" -S)
fi

if [ -z "$commit" ]; then
  echo "shiplog: failed to create policy commit" >&2
  exit 1
fi

if [ -n "$parent" ]; then
  git update-ref -m "$MESSAGE" "$POLICY_REF" "$commit" "$parent"
else
  git update-ref -m "$MESSAGE" "$POLICY_REF" "$commit" 0000000000000000000000000000000000000000
fi

echo "Updated $POLICY_REF -> $commit"
