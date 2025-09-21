#!/usr/bin/env bats

load helpers/common

setup() {
  shiplog_install_cli
  mkdir -p "$HOME/.shiplog/bin" "$HOME/.shiplog/scripts"
  cat <<'SCRIPT' > "$HOME/.shiplog/bin/git-shiplog"
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "$HOME/.shiplog/bin/git-shiplog"
  install -m 0755 "$HOME/.shiplog/bin/git-shiplog" /usr/local/bin/git-shiplog || skip "Cannot install to /usr/local/bin - insufficient permissions"
  install -m 0755 "$HOME/.shiplog/bin/git-shiplog" /usr/local/bin/shiplog || skip "Cannot install to /usr/local/bin - insufficient permissions"

  cat <<'BOSUN' > "$HOME/.shiplog/scripts/bosun"
#!/usr/bin/env bash
exit 0
BOSUN
  chmod +x "$HOME/.shiplog/scripts/bosun"
  ln -sf "$HOME/.shiplog/scripts/bosun" /usr/local/bin/bosun || skip "Cannot create symlink in /usr/local/bin - insufficient permissions"

  # Store original config for restoration
  ORIGINAL_FETCH=$(git config --get-all remote.origin.fetch 2>/dev/null || echo "")
  ORIGINAL_PUSH=$(git config --get-all remote.origin.push 2>/dev/null || echo "")

  git config --add remote.origin.fetch '+refs/_shiplog/*:refs/_shiplog/*'
  git config --add remote.origin.push 'refs/_shiplog/*:refs/_shiplog/*'

  PROFILE="$HOME/.test_profile"
  cat <<PROFILE > "$PROFILE"
# Shiplog
export SHIPLOG_HOME="$HOME/.shiplog"
export PATH="$HOME/.shiplog/bin:$PATH"
PROFILE
  export SHIPLOG_PROFILE="$PROFILE"
  export SHIPLOG_HOME="$HOME/.shiplog"
}

teardown() {
  rm -rf "$HOME/.shiplog" "$HOME/.test_profile" "$HOME/.test_profile.shiplog.bak" 2>/dev/null || true

  if [[ -w /usr/local/bin ]]; then
    rm -f /usr/local/bin/git-shiplog /usr/local/bin/shiplog /usr/local/bin/bosun
  fi

  git config --unset-all remote.origin.fetch '+refs/_shiplog/*:refs/_shiplog/*' 2>/dev/null || true
  git config --unset-all remote.origin.push 'refs/_shiplog/*:refs/_shiplog/*' 2>/dev/null || true

  if [ -n "$ORIGINAL_FETCH" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && git config --add remote.origin.fetch "$line"
    done <<< "$ORIGINAL_FETCH"
  fi
  if [ -n "$ORIGINAL_PUSH" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && git config --add remote.origin.push "$line"
    done <<< "$ORIGINAL_PUSH"
  fi
}

@test "uninstall removes shiplog artifacts" {
  run scripts/uninstall-shiplog.sh --silent
  [ "$status" -eq 0 ]

  [ ! -d "$HOME/.shiplog" ]
  [ ! -e /usr/local/bin/git-shiplog ]
  [ ! -e /usr/local/bin/shiplog ]
  [ ! -e /usr/local/bin/bosun ]

  local fetch_config
  fetch_config=$(git config --get-all remote.origin.fetch 2>/dev/null || echo "")
  [[ "$fetch_config" != *"refs/_shiplog"* ]]

  local push_config
  push_config=$(git config --get-all remote.origin.push 2>/dev/null || echo "")
  [[ "$push_config" != *"refs/_shiplog"* ]]

  # File should exist but not contain Shiplog
  [ -f "$HOME/.test_profile" ]
  run grep 'Shiplog' "$HOME/.test_profile"
  [ "$status" -ne 0 ]
  [ -f "$HOME/.test_profile.shiplog.bak" ]
}
