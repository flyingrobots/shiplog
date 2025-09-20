#!/usr/bin/env bash
set -euo pipefail

# shiplog deps installer: gum + jq + yq
# - Supports: macOS (brew), Debian/Ubuntu (apt), Fedora/RHEL (dnf/yum),
#             Arch (pacman), Alpine (apk), openSUSE (zypper), Snap, or Go fallback for gum.
# - Idempotent: skips installs if already present.
# - Flags: --dry-run (print actions), --silent (less noise)

DRY_RUN=0
SILENT=0
YQ_VERSION=${YQ_VERSION:-v4.44.3}

log() { [ "$SILENT" -eq 1 ] || echo -e "$*"; }
run() { if [ "$DRY_RUN" -eq 1 ]; then echo "+ $*"; else eval "$*"; fi; }

need_sudo() {
  if [ "$(id -u)" -ne 0 ]; then echo "sudo"; else echo ""; fi
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

Installs gum + jq + yq using your package manager (brew/apt/dnf/yum/pacman/apk/zypper),
with Snap/Go fallback for gum and binary fallback for yq if needed. Safe to re-run.
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

install_gum() {
  if have gum; then log "✅ gum already installed ($(gum --version 2>/dev/null || echo gum))"; return; fi

  case "$PM" in
    brew|apt|dnf|yum|pacman|apk|zypper) install_gum_pkgmgr ;;
    *) : ;;
  esac

  if ! have gum; then
    install_gum_snap_or_go
  fi

  if have gum; then
    log "✅ gum installed ($(gum --version 2>/dev/null || echo gum))"
  else
    log "❌ Could not install gum automatically.
Try one of:
  - Homebrew (macOS/Linux): brew tap charmbracelet/tap && brew install gum
  - Snap (Linux): sudo snap install gum
  - Go: go install github.com/charmbracelet/gum@latest && sudo cp \$(go env GOPATH)/bin/gum /usr/local/bin/
"
    exit 1
  fi
}

install_yq_pkgmgr() {
  case "$PM" in
    brew)
      run "brew install yq"
      ;;
    apt)
      run "$(need_sudo) apt-get update"
      run "$(need_sudo) apt-get install -y yq" || return 1
      ;;
    dnf)
      run "$(need_sudo) dnf install -y yq" || return 1
      ;;
    yum)
      run "$(need_sudo) yum install -y yq" || return 1
      ;;
    pacman)
      run "$(need_sudo) pacman -Sy --noconfirm yq" || return 1
      ;;
    apk)
      run "$(need_sudo) apk add --no-cache yq" || return 1
      ;;
    zypper)
      run "$(need_sudo) zypper --non-interactive install yq" || return 1
      ;;
    *)
      return 1
      ;;
  esac
  return 0
}

install_yq_fallback() {
  if have yq; then return 0; fi
  local uname_s uname_m target tmp dest
  uname_s="$(uname -s | tr '[:upper:]' '[:lower:]')"
  uname_m="$(uname -m)"
  case "$uname_s" in
    linux) target="linux" ;;
    darwin) target="darwin" ;;
    *)
      log "❌ Unsupported OS for yq fallback: $uname_s"
      return 1
      ;;
  esac

  case "$uname_m" in
    x86_64|amd64) target="${target}_amd64" ;;
    arm64|aarch64) target="${target}_arm64" ;;
    armv7l) target="${target}_arm" ;;
    *)
      log "❌ Unsupported architecture for yq fallback: $uname_m"
      return 1
      ;;
  esac

  tmp=$(mktemp)
  dest="/usr/local/bin/yq"
  run "curl -fsSL 'https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_${target}' -o '$tmp'"
  run "chmod +x '$tmp'"
  run "$(need_sudo) mv '$tmp' '$dest'"
  return 0
}

install_yq() {
  if have yq; then
    log "✅ yq already installed ($(yq --version 2>/dev/null || echo yq))"
    return
  fi

  if ! install_yq_pkgmgr; then
    install_yq_fallback || {
      log "❌ Could not install yq automatically."
      exit 1
    }
  fi

  if have yq; then
    log "✅ yq installed ($(yq --version 2>/dev/null || echo yq))"
  else
    log "❌ yq installation reported success but binary not found"
    exit 1
  fi
}

log "🔎 Detected OS: $OS, Package manager: $PM"
install_jq
install_gum
install_yq

log ""
log "🎉 Done. Versions:"
log "  - $(jq --version 2>/dev/null || echo 'jq not found')"
log "  - $(gum --version 2>/dev/null || echo 'gum not found')"
log "  - $(yq --version 2>/dev/null || echo 'yq not found')"
