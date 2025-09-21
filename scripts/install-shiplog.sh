#!/usr/bin/env bash
set -euo pipefail

REPO_URL=${SHIPLOG_REPO_URL:-https://github.com/flyingrobots/shiplog.git}
INSTALL_DIR=${SHIPLOG_HOME:-$HOME/.shiplog}
PROFILE_FILE=${SHIPLOG_PROFILE:-}
FORCE_CLONE=0
DRY_RUN=0
SILENT=0
SKIP_PROFILE=0

usage() {
  cat <<'USAGE'
Shiplog bootstrap installer

Usage: install-shiplog.sh [options]

Options:
  --force         overwrite existing installation directory
  --profile FILE  shell profile to update (default: auto-detect)
  --dry-run       show what would happen without making changes
  --silent        reduce logging
  --no-profile    do not modify any shell profile (print instructions instead)
  -h, --help      show this help
USAGE
}

log() { [ "$SILENT" -eq 1 ] || echo "[shiplog-install] $*"; }
run() { if [ "$DRY_RUN" -eq 1 ]; then echo "+ $*"; else eval "$@"; fi; }

while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE_CLONE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --silent) SILENT=1 ;;
    --no-profile) SKIP_PROFILE=1 ;;
    --profile)
      shift || { usage; exit 1; }
      PROFILE_FILE="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown flag: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift || break
done

if [ -z "$PROFILE_FILE" ]; then
  if [ -n "${ZDOTDIR:-}" ] && [ -f "$ZDOTDIR/.zshrc" ]; then
    PROFILE_FILE="$ZDOTDIR/.zshrc"
  elif [ -f "$HOME/.zshrc" ]; then
    PROFILE_FILE="$HOME/.zshrc"
  elif [ -f "$HOME/.bashrc" ]; then
    PROFILE_FILE="$HOME/.bashrc"
  elif [ -f "$HOME/.bash_profile" ]; then
    PROFILE_FILE="$HOME/.bash_profile"
  elif [ -f "$HOME/.profile" ]; then
    PROFILE_FILE="$HOME/.profile"
  fi
fi

log "Install dir: $INSTALL_DIR"
if [ -d "$INSTALL_DIR" ]; then
  if [ "$FORCE_CLONE" -eq 1 ]; then
    log "Removing existing directory"
    run "rm -rf '$INSTALL_DIR'"
  else
    log "Directory already exists; pulling latest"
    run "git -C '$INSTALL_DIR' fetch --all"
    run "git -C '$INSTALL_DIR' reset --hard origin/main"
  fi
else
  log "Cloning repo from $REPO_URL"
  run "git clone '$REPO_URL' '$INSTALL_DIR'"
fi

if [ "$DRY_RUN" -eq 0 ]; then
  log "Running dependency installer"
  (cd "$INSTALL_DIR" && ./install-shiplog-deps.sh ${SILENT:+--silent})
else
  log "Would run dependency installer"
fi

BIN_LINE="export PATH=\"$INSTALL_DIR/bin:\$PATH\""
HOME_LINE="export SHIPLOG_HOME=\"$INSTALL_DIR\""
PROFILE_UPDATED=0

if [ "$SKIP_PROFILE" -eq 0 ] && [ -n "$PROFILE_FILE" ]; then
  touch "$PROFILE_FILE"
  if [ "$DRY_RUN" -eq 0 ]; then
    if [ ! -f "$PROFILE_FILE.bak" ]; then
      log "Creating backup $PROFILE_FILE.bak"
      cp "$PROFILE_FILE" "$PROFILE_FILE.bak"
    fi
    if ! grep -F "SHIPLOG_HOME" "$PROFILE_FILE" >/dev/null 2>&1; then
      log "Updating $PROFILE_FILE"
      printf '\n# Shiplog\nexport SHIPLOG_HOME="%s"\nexport PATH="%s/bin:$PATH"\n' "$INSTALL_DIR" "$INSTALL_DIR" >> "$PROFILE_FILE"
      PROFILE_UPDATED=1
    else
      log "$PROFILE_FILE already references SHIPLOG_HOME; skipping"
    fi
  else
    log "Would append env vars to $PROFILE_FILE"
  fi
else
  log "No shell profile updated; export vars manually:"
  log "  $HOME_LINE"
  log "  $BIN_LINE"
fi

cat <<INFO

Shiplog installed!
Reload your shell or run:
  $HOME_LINE
  $BIN_LINE
Then test with:
  shiplog --help
INFO

if [ "$PROFILE_UPDATED" -eq 1 ]; then
  echo "(Appended PATH setup to $PROFILE_FILE)"
fi
