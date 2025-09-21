# syntax=docker/dockerfile:1
FROM debian:bookworm-slim

ARG ENABLE_SIGNING=false
ARG DEBIAN_FRONTEND=noninteractive
ARG GUM_VERSION=0.13.0

# Base dependencies for shiplog tests
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       ca-certificates \
       curl \
       jq \
       bats \
       gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install gum from architecture-specific tarball
RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in \
         amd64)  gusuf=Linux_x86_64 ;; \
         arm64)  gusuf=Linux_arm64 ;; \
         armhf)  gusuf=Linux_armv6 ;; \
         *) echo "Unsupported arch: $arch" >&2 && exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_${gusuf}.tar.gz" \
         -o /tmp/gum.tgz \
    && tar -C /usr/local/bin -xzf /tmp/gum.tgz gum \
    && rm -f /tmp/gum.tgz \
    && chmod +x /usr/local/bin/gum \
    && gum --version

WORKDIR /workspace

# Test runner script (sets up throw-away repo, installs gum stub, executes bats)
RUN cat <<'SCRIPT' > /usr/local/bin/run-tests
#!/usr/bin/env bash
set -euo pipefail

export GIT_ALLOW_REFNAME_COMPONENTS_STARTING_WITH_DOT=1
: "${TEST_ENV:=prod}"
: "${TEST_AUTHOR_NAME:=Shiplog Test}"
: "${TEST_AUTHOR_EMAIL:=shiplog-test@example.local}"
export SHIPLOG_HOME=${SHIPLOG_HOME:-/workspace}
export SHIPLOG_LIB_DIR=${SHIPLOG_LIB_DIR:-/workspace/lib}
export SHIPLOG_REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}
export SHIPLOG_NOTES_REF=${SHIPLOG_NOTES_REF:-refs/_shiplog/notes/logs}

# Optional signing bootstrap (if ENABLE_SIGNING build-arg was true)
if [ "${ENABLE_SIGNING:-false}" = "true" ]; then
  if ! command -v gpg >/dev/null; then
    echo "gnupg missing" >&2
    exit 1
  fi
  if ! gpg --list-secret-keys --with-colons | grep -q "^sec:"; then
    echo "Generating throw-away GPG key"
    mkdir -p ~/.gnupg
    chmod 700 ~/.gnupg
    printf "allow-loopback-pinentry
" > ~/.gnupg/gpg-agent.conf
    export GPG_TTY="$(tty 2>/dev/null || echo /dev/null)"
    gpgconf --kill gpg-agent >/dev/null 2>&1 || true
    gpg --batch --pinentry-mode loopback --passphrase '' --quick-gen-key "Shiplog Test <shiplog-test@example.local>" default default never >/dev/null
  fi
  KEYID="$(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5; exit}')"
  git config --global user.signingkey "$KEYID"
  git config --global commit.gpgsign true
  git config --global gpg.program gpg
else
  export SHIPLOG_SIGN=${SHIPLOG_SIGN:-0}
fi

console_log() {
  printf '%s
' "$*"
}

echo "Setting up throw-away repo"
TMPREPO="$(mktemp -d)"
cd "$TMPREPO"
git init -q
git config user.name  "$TEST_AUTHOR_NAME"
git config user.email "$TEST_AUTHOR_EMAIL"
git commit --allow-empty -m init >/dev/null

# Bring in shiplog script from mounted workspace
if [ ! -f /workspace/bin/shiplog ]; then
  echo "Missing /workspace/bin/shiplog. Mount your project into /workspace." >&2
  exit 1
fi
install -m 0755 /workspace/bin/shiplog /usr/local/bin/shiplog

# Create a non-interactive gum stub for CI runs
cat <<'GUM' > /tmp/gum-ci
#!/usr/bin/env bash
set -euo pipefail

subcmd="${1:-}"
if [ $# -gt 0 ]; then
  shift
fi
case "$subcmd" in
  input)
    value=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --value)
          shift
          value="${1:-}"
          ;;
        --placeholder|--header|--title|--width|--height|--cursor|--password)
          shift
          ;;
        --)
          shift
          break
          ;;
        *)
          break
          ;;
      esac
      [ $# -gt 0 ] || break
      shift || break
    done
    printf "%s
" "${GUM_INPUT_OVERRIDE:-$value}"
    ;;
  choose)
    choice=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --*)
          shift
          ;;
        *)
          choice="$1"
          break
          ;;
      esac
    done
    printf "%s
" "${GUM_CHOICE:-$choice}"
    ;;
  confirm)
    exit 0
    ;;
  spin)
    while [ $# -gt 0 ]; do
      if [ "$1" = "--" ]; then
        shift
        break
      fi
      shift
    done
    if [ $# -gt 0 ]; then
      "$@"
    fi
    ;;
  style)
    title=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --title)
          shift
          title="${1:-}"
          ;;
        --)
          shift
          break
          ;;
        *)
          shift
          ;;
      esac
    done
    if [ -n "$title" ]; then
      printf "%s
" "$title"
    fi
    if [ $# -gt 0 ]; then
      printf "%s
" "$*"
    else
      cat
    fi
    ;;
  log)
    # TODO: Implement actual log functionality
    exit 0
    ;;
  table)
    header=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --columns)
          shift
          if [ -n "$header" ]; then
            header="${header}	${1:-}"
          else
            header="${1:-}"
          fi
          ;;
        --)
          shift
          break
          ;;
        *)
          shift
          ;;
      esac
    done
    if [ -n "$header" ]; then
      printf "%s
" "$header"
    fi
    if [ $# -gt 0 ]; then
      printf "%s
" "$*"
    else
      cat
    fi
    ;;
  *)
    if [ $# -gt 0 ]; then
      printf "%s
" "$*"
    else
      cat
    fi
    ;;
 esac
GUM
chmod +x /tmp/gum-ci
export GUM=/tmp/gum-ci

# Refspecs for hidden refs (so tests that fetch/push work if needed)
git config --add remote.origin.fetch "+${SHIPLOG_REF_ROOT}/*:${SHIPLOG_REF_ROOT}/*" || true
git config --add remote.origin.push  "${SHIPLOG_REF_ROOT}/*:${SHIPLOG_REF_ROOT}/*"  || true
git config core.logAllRefUpdates true

echo "Running bats tests"
if compgen -G "/workspace/tests/*.bats" > /dev/null; then
  bats -r /workspace/tests
else
  echo "No tests found at /workspace/tests/*.bats"
fi
SCRIPT
RUN chmod +x /usr/local/bin/run-tests

ENV ENABLE_SIGNING=${ENABLE_SIGNING}

ENTRYPOINT ["/usr/local/bin/run-tests"]
