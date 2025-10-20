#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_standard_setup
  git shiplog init >/dev/null
  # Use default test identity from helpers (allowed by policy)
}

teardown() {
  shiplog_standard_teardown
}

@test "publish pushes journal regardless of auto-push settings" {
  # Set env to auto-push, git config to 0, and pass --push to publish
  export SHIPLOG_AUTO_PUSH=0
  git config shiplog.autoPush false
  # Create a bare remote and set as origin
  shiplog_use_temp_remote origin REMOTE_DIR
  # Write an entry locally (no push)
  export SHIPLOG_BORING=1
  export SHIPLOG_SERVICE=pub
  export SHIPLOG_STATUS=success
  export SHIPLOG_REASON=t
  export SHIPLOG_REGION=us
  export SHIPLOG_CLUSTER=c
  export SHIPLOG_NAMESPACE=ns
  run git shiplog write --env staging
  [ "$status" -eq 0 ]
  # Publish should push even if auto-push settings are disabled (explicit action)
  run git shiplog publish --env staging
  [ "$status" -eq 0 ]
  # Verify the remote journal ref exists
  run git --git-dir="$REMOTE_DIR" for-each-ref 'refs/_shiplog/journal/staging' --format='%(refname)'
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "refs/_shiplog/journal/staging"
}

@test "auto-push honors SHIPLOG_REMOTE and bypasses pre-push hook" {
  export SHIPLOG_REMOTE=mirror
  export SHIPLOG_BORING=1
  export SHIPLOG_SERVICE=remote
  export SHIPLOG_STATUS=success
  export SHIPLOG_REASON=autopush
  export SHIPLOG_REGION=us-test
  export SHIPLOG_CLUSTER=cluster-1
  export SHIPLOG_NAMESPACE=ns-remote
  git shiplog init >/dev/null
  shiplog_use_temp_remote "$SHIPLOG_REMOTE" REMOTE_DIR
  cat > .git/hooks/pre-push <<'EOF'
#!/usr/bin/env bash
echo "hook" >> .git/prepush.log
exit 1
EOF
  chmod +x .git/hooks/pre-push
  run git shiplog write --env staging
  local write_output="$output"
  if [ "$status" -ne 0 ]; then
    echo "$write_output" >&2
    if [ -f .git/prepush.log ]; then
      echo "pre-push hook output:" >&2
      cat .git/prepush.log >&2
    fi
  fi
  [ "$status" -eq 0 ]
  [ ! -f .git/prepush.log ]
  run git --git-dir="$REMOTE_DIR" for-each-ref 'refs/_shiplog/journal/staging' --format='%(refname)'
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "refs/_shiplog/journal/staging"
  rm -f .git/hooks/pre-push .git/prepush.log
}

@test "publish uses SHIPLOG_REMOTE and skips pre-push hook" {
  export SHIPLOG_REMOTE=mirror
  export SHIPLOG_AUTO_PUSH=0
  export SHIPLOG_BORING=1
  export SHIPLOG_SERVICE=remote
  export SHIPLOG_STATUS=success
  export SHIPLOG_REASON=publish
  export SHIPLOG_REGION=us-test
  export SHIPLOG_CLUSTER=cluster-2
  export SHIPLOG_NAMESPACE=ns-remote
  git shiplog init >/dev/null
  shiplog_use_temp_remote "$SHIPLOG_REMOTE" REMOTE_DIR
  cat > .git/hooks/pre-push <<'EOF'
#!/usr/bin/env bash
echo "hook" >> .git/prepush-publish.log
exit 1
EOF
  chmod +x .git/hooks/pre-push
  run git shiplog write --env staging
  local write_output="$output"
  if [ "$status" -ne 0 ]; then
    echo "$write_output" >&2
    if [ -f .git/prepush.log ]; then
      echo "pre-push hook output:" >&2
      cat .git/prepush.log >&2
    fi
  fi
  [ "$status" -eq 0 ]
  run git shiplog publish --env staging
  local publish_output="$output"
  if [ "$status" -ne 0 ]; then
    echo "$publish_output" >&2
    if [ -f .git/prepush-publish.log ]; then
      echo "pre-push hook output:" >&2
      cat .git/prepush-publish.log >&2
    fi
  fi
  [ "$status" -eq 0 ]
  [ ! -f .git/prepush-publish.log ]
  run git --git-dir="$REMOTE_DIR" for-each-ref 'refs/_shiplog/journal/staging' --format='%(refname)'
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "refs/_shiplog/journal/staging"
  rm -f .git/hooks/pre-push .git/prepush-publish.log
}
