#!/usr/bin/env bash
set -euo pipefail

# This script sets up a development environment for shiplog by symlinking
# the local git repository to the standard shiplog installation directory.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="${SHIPLOG_HOME:-$HOME/.shiplog}"

log() {
  echo "[shiplog-dev-install] $*"
}

log "Repository root: $REPO_ROOT"
log "Install directory: $INSTALL_DIR"

if [ -e "$INSTALL_DIR" ] || [ -L "$INSTALL_DIR" ]; then
  log "Removing existing installation at $INSTALL_DIR"
  rm -rf "$INSTALL_DIR"
fi

log "Creating symlink: $INSTALL_DIR -> $REPO_ROOT"
ln -s "$REPO_ROOT" "$INSTALL_DIR"

cat <<INFO

Shiplog dev mode enabled!
The directory '$INSTALL_DIR' now points to your local repository.

To use the 'git-shiplog' command, ensure '$INSTALL_DIR/bin' is in your PATH.
You can do this by adding the following to your shell profile (~/.zshrc, ~/.bashrc, etc.):

  export SHIPLOG_HOME="$INSTALL_DIR"
  export PATH="\$SHIPLOG_HOME/bin:\$PATH"

Reload your shell for changes to take effect.
Then test with:
  git shiplog --version
INFO
