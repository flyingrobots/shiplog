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
  install -m 0755 "$HOME/.shiplog/bin/git-shiplog" /usr/local/bin/git-shiplog
  install -m 0755 "$HOME/.shiplog/bin/git-shiplog" /usr/local/bin/shiplog

  cat <<'BOSUN' > "$HOME/.shiplog/scripts/bosun"
#!/usr/bin/env bash
exit 0
BOSUN
  chmod +x "$HOME/.shiplog/scripts/bosun"
  ln -sf "$HOME/.shiplog/scripts/bosun" /usr/local/bin/bosun

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
  rm -rf "$HOME/.shiplog" "$HOME/.test_profile" "$HOME/.test_profile.shiplog.bak" || true
  rm -f /usr/local/bin/git-shiplog /usr/local/bin/shiplog /usr/local/bin/bosun || true
  git config --unset-all remote.origin.fetch '+refs/_shiplog/*:refs/_shiplog/*' >/dev/null 2>&1 || true
  git config --unset-all remote.origin.push 'refs/_shiplog/*:refs/_shiplog/*' >/dev/null 2>&1 || true
}

@test "uninstall removes shiplog artifacts" {
  run scripts/uninstall-shiplog.sh --silent
  [ "$status" -eq 0 ]

  [ ! -d "$HOME/.shiplog" ]
  [ ! -L /usr/local/bin/git-shiplog ]
  [ ! -L /usr/local/bin/shiplog ]
  [ ! -L /usr/local/bin/bosun ]

  run bash -lc 'git config --get-all remote.origin.fetch || true'
  [[ "$output" != *"refs/_shiplog"* ]]

  run bash -lc 'git config --get-all remote.origin.push || true'
  [[ "$output" != *"refs/_shiplog"* ]]

  run bash -lc "grep 'Shiplog' '$HOME/.test_profile'"
  [ "$status" -ne 0 ]
  [ -f "$HOME/.test_profile.shiplog.bak" ]
}
