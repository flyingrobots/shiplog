#!/usr/bin/env bash
set -euo pipefail

# shiplog deps installer: jq
# - Supports: macOS (brew), Debian/Ubuntu (apt), Fedora/RHEL (dnf/yum),
#             Arch (pacman), Alpine (apk), openSUSE (zypper).
# - Idempotent: skips installs if already present.
# - Flags: --dry-run (print actions), --silent (less noise)

DRY_RUN=0
SILENT=0

log() { [ "$SILENT" -eq 1 ] || echo -e "$*"; }
run() { if [ "$DRY_RUN" -eq 1 ]; then echo "+ $*"; else eval "$*"; fi; }

die() { echo "❌ $*" >&2; exit 1; }

need_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    printf '%s' ""
  elif command -v sudo >/dev/null 2>&1; then
    printf '%s' "sudo"
  else
    die "Require root privileges; rerun as root or install sudo"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s 2>/dev/null || echo unknown)"
PM=""
if have brew; then PM="brew"
elif have apt-get; then PM="apt"
elif have dnf; then PM="dnf"
elif have yum; then PM="yum"
elif have pacman; then PM="pacman"
elif have apk; then PM="apk"
elif have zypper; then PM="zypper"
else PM="unknown"
fi

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --silent) SILENT=1 ;;
    -h|--help)
      cat <<'USAGE'
Usage: $0 [--dry-run] [--silent]

Installs jq using your package manager (brew/apt/dnf/yum/pacman/apk/zypper).
Safe to re-run.
USAGE
      exit 0
      ;;
  esac
done

install_jq() {
  if have jq; then
    log "✅ jq already installed ($(jq --version 2>/dev/null || echo jq))"
    return
  fi
  case "$PM" in
    brew) run "brew install jq" ;;
    apt)
      run "$(need_sudo) apt-get update"
      run "$(need_sudo) apt-get install -y jq"
      ;;
    dnf) run "$(need_sudo) dnf install -y jq" ;;
    yum) run "$(need_sudo) yum install -y jq" ;;
    pacman)
      run "$(need_sudo) pacman -Sy --noconfirm jq"
      ;;
    apk) run "$(need_sudo) apk add --no-cache jq" ;;
    zypper) run "$(need_sudo) zypper --non-interactive install jq" ;;
    *)
      die "No supported package manager found; install jq manually."
      ;;
  esac
  log "✅ jq installed ($(jq --version 2>/dev/null || echo jq))"
}

log "🔎 Detected OS: $OS, Package manager: $PM"
install_jq

log ""
log "🎉 Done. Versions:"
log "  - $(jq --version 2>/dev/null || echo 'jq not found')"
