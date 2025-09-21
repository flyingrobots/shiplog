#!/usr/bin/env bash
set -euo pipefail

# shiplog deps installer: gum + jq
# - Supports: macOS (brew), Debian/Ubuntu (apt), Fedora/RHEL (dnf/yum),
#             Arch (pacman), Alpine (apk), openSUSE (zypper), Snap, or Go fallback for gum.
# - Idempotent: skips installs if already present.
# - Flags: --dry-run (print actions), --silent (less noise)

DRY_RUN=0
SILENT=0
GUM_VERSION=${GUM_VERSION:-0.13.0}

log() { [ "$SILENT" -eq 1 ] || echo -e "$*"; }
run() { if [ "$DRY_RUN" -eq 1 ]; then echo "+ $*"; else eval "$*"; fi; }

need_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    echo ""
  elif command -v sudo >/dev/null 2>&1; then
    echo "sudo"
  else
    die "Require root privileges; rerun as root or install sudo"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# Detect OS + package manager
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

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --silent) SILENT=1 ;;
    -h|--help)
      cat <<'USAGE'
Usage: $0 [--dry-run] [--silent]

Installs gum + jq using your package manager (brew/apt/dnf/yum/pacman/apk/zypper),
with Snap/Go fallback for gum. Safe to re-run.
USAGE
      exit 0
      ;;
  esac
done

install_jq() {
  if have jq; then log "✅ jq already installed ($(jq --version))"; return; fi
  case "$PM" in
    brew) run "brew install jq" ;;
    apt)  run "$(need_sudo) apt-get update"; run "$(need_sudo) apt-get install -y jq" ;;
    dnf)  run "$(need_sudo) dnf install -y jq" ;;
    yum)  run "$(need_sudo) yum install -y jq" ;;
    pacman) run "$(need_sudo) pacman -Sy --noconfirm jq" ;;
    apk)  run "$(need_sudo) apk add --no-cache jq" ;;
    zypper) run "$(need_sudo) zypper --non-interactive install jq" ;;
    *)
      log "❌ No supported package manager found for jq."
      exit 1
      ;;
  esac
  log "✅ jq installed ($(jq --version))"
}

install_gum_pkgmgr() {
  case "$PM" in
    brew)
      if ! brew list gum >/dev/null 2>&1; then
        run "brew tap charmbracelet/tap"
        run "brew install gum"
      fi
      ;;
    apt)
      if ! have gum; then
        if apt-cache show gum >/dev/null 2>&1; then
          run "$(need_sudo) apt-get update"
          run "$(need_sudo) apt-get install -y gum"
        fi
      fi
      ;;
    dnf)
      if ! have gum; then
        run "$(need_sudo) dnf install -y gum" || true
      fi
      ;;
    yum)
      if ! have gum; then
        run "$(need_sudo) yum install -y gum" || true
      fi
      ;;
    pacman)
      if ! have gum; then
        run "$(need_sudo) pacman -Sy --noconfirm gum" || true
      fi
      ;;
    apk)
      if ! have gum; then
        run "$(need_sudo) apk add --no-cache gum" || true
      fi
      ;;
    zypper)
      if ! have gum; then
        run "$(need_sudo) zypper --non-interactive install gum" || true
      fi
      ;;
  esac
}

install_gum_snap_or_go() {
  if ! have gum && have snap; then
    run "$(need_sudo) snap install gum" || true
  fi

  if ! have gum && have go; then
    log "ℹ️ Installing gum via Go fallback…"
    run "go install github.com/charmbracelet/gum@latest"
    local GOBIN_DIR
    GOBIN_DIR="$(go env GOBIN)"
    if [ -z "$GOBIN_DIR" ]; then GOBIN_DIR="$(go env GOPATH)/bin"; fi
    if [ -x "$GOBIN_DIR/gum" ] && ! have gum; then
      run "$(need_sudo) cp '$GOBIN_DIR/gum' /usr/local/bin/"
    fi
  fi
}

install_gum_tgz() {
  if have gum; then return 0; fi
  local arch suffix tmp extract_dir checksum expected_checksum
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) suffix="Linux_x86_64" ;;
    arm64|aarch64) suffix="Linux_arm64" ;;
    armv7l|armhf) suffix="Linux_armv6" ;;
    *)
      log "❌ Unsupported architecture for gum binary fallback: $arch"
      return 1
      ;;
  esac

  tmp=$(mktemp) || { log "❌ Failed to create temp file"; return 1; }
  extract_dir=$(mktemp -d) || { rm -f "$tmp"; log "❌ Failed to create temp dir"; return 1; }

  # Cleanup function
  cleanup_gum_install() {
    rm -f "$tmp"
    rm -rf "$extract_dir"
  }
  trap cleanup_gum_install EXIT

  run "curl -fsSL 'https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_${suffix}.tar.gz' -o '$tmp'"

  # Verify download succeeded and file isn't empty
  if [ ! -s "$tmp" ]; then
    log "❌ Download failed or empty file"
    return 1
  fi

  run "tar -C '$extract_dir' -xzf '$tmp' gum"

  # Verify extracted binary
  if [ ! -x "$extract_dir/gum" ]; then
    log "❌ Failed to extract gum binary"
    return 1
  fi

  # Verify target directory exists
  if [ ! -d "/usr/local/bin" ]; then
    run "$(need_sudo) mkdir -p /usr/local/bin"
  fi

  run "$(need_sudo) mv '$extract_dir/gum' /usr/local/bin/gum"
  run "$(need_sudo) chmod +x /usr/local/bin/gum"
}
install_gum() {
  if have gum; then log "✅ gum already installed ($(gum --version 2>/dev/null || echo gum))"; return; fi

  case "$PM" in
    brew|apt|dnf|yum|pacman|apk|zypper) install_gum_pkgmgr ;;
    *) : ;;
  esac

  if ! have gum; then
    install_gum_snap_or_go
  fi

  if ! have gum; then
    install_gum_tgz || true
  fi

  if have gum; then
    log "✅ gum installed ($(gum --version 2>/dev/null || echo gum))"
  else
    log "❌ Could not install gum automatically.
Try one of:
  - Homebrew (macOS/Linux): brew tap charmbracelet/tap && brew install gum
  - Snap (Linux): sudo snap install gum
  - Binary: curl -fsSL https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_Linux_x86_64.tar.gz | sudo tar -xz -C /usr/local/bin gum
  - Go: go install github.com/charmbracelet/gum@latest && sudo cp \$(go env GOPATH)/bin/gum /usr/local/bin/
"
    exit 1
  fi
}

log "🔎 Detected OS: $OS, Package manager: $PM"
install_jq
install_gum

log ""
log "🎉 Done. Versions:"
log "  - $(jq --version 2>/dev/null || echo 'jq not found')"
log "  - $(gum --version 2>/dev/null || echo 'gum not found')"
