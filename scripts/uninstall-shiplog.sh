#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR=${SHIPLOG_HOME:-$HOME/.shiplog}
PROFILE_FILE=${SHIPLOG_PROFILE:-}
DRY_RUN=0
SILENT=0
NO_BACKUP=0
FORCE=0

resolve_remote_name() {
  local remote="${SHIPLOG_REMOTE:-}"
  if [ -n "$remote" ]; then
    printf '%s' "$remote"
    return
  fi
  local cfg
  cfg=$(git config --get shiplog.remote 2>/dev/null || true)
  if [ -n "$cfg" ]; then
    printf '%s' "$cfg"
  else
    printf '%s' "origin"
  fi
}

usage() {
  cat <<'USAGE'
Shiplog uninstaller

Usage: uninstall-shiplog.sh [options]

Options:
  --dry-run       show actions without performing them
  --silent        reduce logging
  --no-backup     do not create profile backups before editing
  --profile FILE  explicit profile to edit (default: auto-detect)
  --force         proceed even if local refs are ahead of origin
  -h, --help      show this help
USAGE
}

log() { [ "$SILENT" -eq 1 ] || echo "[shiplog-uninstall] $*"; }
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  "$@" || return $?
}

sanitize_profile() {
  local profile="$1" install_dir="$2"
  local tmp
  tmp=$(mktemp) || return 1
  if ! awk -v dir="$install_dir" '
    {
      stripped=$0
      sub(/^[[:space:]]+/, "", stripped)
      sub(/[[:space:]]+$/, "", stripped)
      if (stripped == "# Shiplog") next
      if (index($0, dir) > 0) {
        if (stripped ~ /^export[[:space:]]+SHIPLOG_HOME=/) next
        if (stripped ~ /^export[[:space:]]+PATH=/ && index($0, dir "/bin") > 0) next
      }
      print $0
    }
  ' "$profile" > "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$profile"
}

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
  local key="$1" target="$2"
  local values=()
  mapfile -t values < <(git config --get-all "$key" 2>/dev/null || true)
  [ ${#values[@]} -gt 0 ] || return

  local keep=()
  for val in "${values[@]}"; do
    if [ "$val" != "$target" ]; then
      keep+=("$val")
    fi
  done

  if [ ${#keep[@]} -eq ${#values[@]} ]; then
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ git config --unset-all $key"
    for val in "${keep[@]}"; do
      echo "+ git config --add $key '$val'"
    done
    return
  fi

  git config --unset-all "$key" || true
  for val in "${keep[@]}"; do
    git config --add "$key" "$val"
  done
}

git_config_remove_refspec remote.origin.fetch "+refs/_shiplog/*:refs/_shiplog/*"
git_config_remove_refspec remote.origin.push "refs/_shiplog/*:refs/_shiplog/*"

unpublished_refs=()
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git config --get remote.origin.url >/dev/null 2>&1; then
  if command -v ssh >/dev/null 2>&1; then
    if ! run git fetch origin 'refs/_shiplog/*:refs/_shiplog/*'; then
      log "Warning: unable to fetch refs/_shiplog/*"
    fi
  else
    log "Warning: ssh client not available; skipping remote refs sync"
  fi
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    local_tip=$(git rev-parse "$ref" 2>/dev/null || echo "")
    [ -n "$local_tip" ] || continue
    remote_tip=$(timeout 30 git ls-remote origin "$ref" 2>/dev/null | awk '{print $1}' || echo "")
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
  remote_name=$(resolve_remote_name)
  log "Aborting uninstall: local Shiplog refs not pushed to $remote_name:"
  for ref in "${unpublished_refs[@]}"; do
    echo "  $ref"
  done
  log "Push them with: git push --no-verify $remote_name <ref> (or rerun with --force)."
  exit 1
fi

if [ ${#unpublished_refs[@]} -gt 0 ] && [ "$FORCE" -eq 1 ] && [ "$SILENT" -ne 1 ]; then
  log "Proceeding despite unpushed refs: ${unpublished_refs[*]}"
fi

GIT_SHIPLOG_TARGET="$INSTALL_DIR/bin/git-shiplog"
BOSUN_TARGET="$INSTALL_DIR/scripts/bosun"

if [ -e "/usr/local/bin/git-shiplog" ]; then
  if [ -L "/usr/local/bin/git-shiplog" ] && [ "$(readlink "/usr/local/bin/git-shiplog")" = "$GIT_SHIPLOG_TARGET" ]; then
    log "Removing /usr/local/bin/git-shiplog"
    run rm -f /usr/local/bin/git-shiplog
  elif cmp -s "/usr/local/bin/git-shiplog" "$GIT_SHIPLOG_TARGET" 2>/dev/null; then
    log "Removing /usr/local/bin/git-shiplog (matching installed copy)"
    run rm -f /usr/local/bin/git-shiplog
  else
    log "Skipping removal of /usr/local/bin/git-shiplog (custom install detected)"
  fi
fi

for shim in shiplog bosun; do
  if command -v "$shim" >/dev/null 2>&1; then
    shim_path="$(command -v "$shim")"
    target="$GIT_SHIPLOG_TARGET"
    [ "$shim" = "bosun" ] && target="$BOSUN_TARGET"
    if [ -L "$shim_path" ] && [ "$(readlink "$shim_path")" = "$target" ]; then
      log "Removing $shim shim at $shim_path"
      run rm -f "$shim_path"
    elif cmp -s "$shim_path" "$target" 2>/dev/null; then
      log "Removing $shim shim at $shim_path (matching installed copy)"
      run rm -f "$shim_path"
    fi
  fi
done

if [ -d "$INSTALL_DIR" ]; then
  log "Removing $INSTALL_DIR"
  run rm -rf "$INSTALL_DIR"
else
  log "Install directory $INSTALL_DIR not found"
fi

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
    if ! sanitize_profile "$PROFILE_FILE" "$INSTALL_DIR"; then
      log "Error: failed to clean $PROFILE_FILE; leaving original in place."
    fi
  fi
else
  log "Profile file not found or unspecified; remove PATH/SHIPLOG_HOME entries manually if needed."
fi

log "Shiplog uninstall complete"
if [ "$SILENT" -ne 1 ]; then
  echo "Remote refs under refs/_shiplog/* were left intact on your remotes; remove them manually only if you intend to delete history."
fi
