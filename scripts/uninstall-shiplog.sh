#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR=${SHIPLOG_HOME:-$HOME/.shiplog}
PROFILE_FILE=${SHIPLOG_PROFILE:-}
DRY_RUN=0
SILENT=0
NO_BACKUP=0
FORCE=0

usage() {
  cat <<'USAGE'
Shiplog uninstaller

Usage: uninstall-shiplog.sh [options]

Options:
  --dry-run     show actions without performing them
  --silent      reduce logging
  --no-backup   do not create profile backups before editing
  --profile FILE  explicit profile to edit (default: auto-detect)
  -h, --help    show this help
USAGE
}

log() { [ "$SILENT" -eq 1 ] || echo "[shiplog-uninstall] $*"; }
run() { if [ "$DRY_RUN" -eq 1 ]; then echo "+ $*"; else "$@"; fi; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --silent) SILENT=1 ;;
    --no-backup) NO_BACKUP=1 ;;
    --profile)
      shift || { usage; exit 1; }
      PROFILE_FILE="$1"
      ;;
    --force) FORCE=1 ;;
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

git_config_remove_refspec() {
  local key="$1" value="$2"
  if git config --get-all "$key" 2>/dev/null | grep -Fxq "$value"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "+ git config --unset-all $key '$value'"
    else
      git config --unset-all "$key" "$value"
    fi
  fi
}

git_config_remove_refspec remote.origin.fetch "+refs/_shiplog/*:refs/_shiplog/*"
git_config_remove_refspec remote.origin.push "refs/_shiplog/*:refs/_shiplog/*"

unpublished_refs=()
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git config --get remote.origin.url >/dev/null 2>&1; then
  run "git fetch origin 'refs/_shiplog/*:refs/_shiplog/*'" || log "Warning: unable to fetch refs/_shiplog/*"
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    local_tip=$(git rev-parse "$ref" 2>/dev/null || echo "")
    [ -n "$local_tip" ] || continue
    remote_tip=$(git ls-remote origin "$ref" | awk '{print $1}')
    if [ -z "$remote_tip" ]; then
      unpublished_refs+=("$ref")
      continue
    fi
    if [ "$local_tip" = "$remote_tip" ]; then
      continue
    fi
    if git merge-base --is-ancestor "$remote_tip" "$local_tip" >/dev/null 2>&1; then
      unpublished_refs+=("$ref")
    fi
  done < <(git for-each-ref --format='%(refname)' refs/_shiplog)
fi

if [ ${#unpublished_refs[@]} -gt 0 ] && [ "$FORCE" -eq 0 ]; then
  log "Aborting uninstall: local Shiplog refs not pushed to origin:"
  for ref in "${unpublished_refs[@]}"; do
    echo "  $ref"
  done
  log "Push them with: git push origin <ref> (or rerun with --force)."
  exit 1
fi

if [ ${#unpublished_refs[@]} -gt 0 ] && [ "$FORCE" -eq 1 ] && [ "$SILENT" -ne 1 ]; then
  log "Proceeding despite unpushed refs: ${unpublished_refs[*]}"
fi

GIT_SHIPLOG_TARGET="$INSTALL_DIR/bin/git-shiplog"
BOSUN_TARGET="$INSTALL_DIR/scripts/bosun"

if [ -d "$INSTALL_DIR" ]; then
  log "Removing $INSTALL_DIR"
  run "rm -rf '$INSTALL_DIR'"
else
  log "Install directory $INSTALL_DIR not found"
fi

if [ -L "/usr/local/bin/git-shiplog" ] && [ "$(readlink "/usr/local/bin/git-shiplog")" = "$GIT_SHIPLOG_TARGET" ]; then
  log "Removing /usr/local/bin/git-shiplog"
  run "rm -f /usr/local/bin/git-shiplog"
fi

for shim in shiplog bosun; do
  if command -v "$shim" >/dev/null 2>&1; then
    shim_path="$(command -v "$shim")"
    target="$GIT_SHIPLOG_TARGET"
    [ "$shim" = "bosun" ] && target="$BOSUN_TARGET"
    if [ -L "$shim_path" ] && [ "$(readlink "$shim_path")" = "$target" ]; then
      log "Removing $shim shim at $shim_path"
      run "rm -f '$shim_path'"
    fi
  fi
done

if [ -n "$PROFILE_FILE" ] && [ -f "$PROFILE_FILE" ]; then
  if [ "$DRY_RUN" -eq 0 ] && [ "$NO_BACKUP" -eq 0 ]; then
    if [ ! -f "$PROFILE_FILE.shiplog.bak" ]; then
      log "Creating backup $PROFILE_FILE.shiplog.bak"
      cp "$PROFILE_FILE" "$PROFILE_FILE.shiplog.bak"
    fi
  fi
  log "Cleaning Shiplog lines from $PROFILE_FILE"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ removing Shiplog entries from $PROFILE_FILE"
  else
    python - "$PROFILE_FILE" "$INSTALL_DIR" <<'PY'
import sys
from pathlib import Path
profile = Path(sys.argv[1])
install_dir = sys.argv[2]
lines = profile.read_text().splitlines()
filtered = []
for line in lines:
    stripped = line.strip()
    if stripped.startswith('# Shiplog'):
        continue
    if 'SHIPLOG_HOME' in stripped and install_dir in stripped:
        continue
    if install_dir + '/bin:$PATH' in stripped:
        continue
    filtered.append(line)
profile.write_text('\n'.join(filtered) + ('\n' if filtered else ''))
PY
  fi
else
  log "Profile file not found or unspecified; remove PATH/SHIPLOG_HOME entries manually if needed."
fi

log "Shiplog uninstall complete"
if [ "$SILENT" -ne 1 ]; then
  echo "Remote refs under refs/_shiplog/* were left intact on your remotes; remove them manually only if you intend to delete history."
fi

