# syntax=docker/dockerfile:1
FROM debian:bookworm-slim

ARG ENABLE_SIGNING=false
ARG DEBIAN_FRONTEND=noninteractive

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

WORKDIR /workspace

# Test runner script (sets up throw-away repo, executes bats)
RUN cat <<'SCRIPT' > /usr/local/bin/run-tests
#!/usr/bin/env bash
set -euo pipefail

export GIT_ALLOW_REFNAME_COMPONENTS_STARTING_WITH_DOT=1
: "${TEST_ENV:=prod}"
: "${TEST_AUTHOR_NAME:=Shiplog Test}"
: "${TEST_AUTHOR_EMAIL:=shiplog-test@example.local}"
SRC_WORKSPACE=${SHIPLOG_HOME:-/workspace}
TEST_ROOT=$(mktemp -d)
cp -a "$SRC_WORKSPACE/." "$TEST_ROOT/shiplog"
export SHIPLOG_HOME="$TEST_ROOT/shiplog"
export SHIPLOG_LIB_DIR="$SHIPLOG_HOME/lib"
cd "$SHIPLOG_HOME"
export PATH="$SHIPLOG_HOME/bin:$PATH"
export SHIPLOG_BOSUN_BIN="${SHIPLOG_BOSUN_BIN:-$SHIPLOG_HOME/scripts/bosun}"
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
  cat <<'GPGWRAP' > /usr/local/bin/gpg-loopback
#!/usr/bin/env bash
exec gpg --batch --pinentry-mode loopback "$@"
GPGWRAP
  chmod +x /usr/local/bin/gpg-loopback
  git config --global user.signingkey "$KEYID"
  git config --global commit.gpgsign true
  git config --global gpg.program /usr/local/bin/gpg-loopback
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
if [ ! -f "${SHIPLOG_HOME}/bin/git-shiplog" ]; then
  echo "Missing ${SHIPLOG_HOME}/bin/git-shiplog. Mount your project into ${SHIPLOG_HOME}." >&2
  exit 1
fi
install -m 0755 "${SHIPLOG_HOME}/bin/git-shiplog" /usr/local/bin/git-shiplog

# Refspecs for hidden refs (so tests that fetch/push work if needed)
git config --add remote.origin.fetch "+${SHIPLOG_REF_ROOT}/*:${SHIPLOG_REF_ROOT}/*" || true
git config --add remote.origin.push  "${SHIPLOG_REF_ROOT}/*:${SHIPLOG_REF_ROOT}/*"  || true
git config core.logAllRefUpdates true

echo "Running bats tests"
if compgen -G "$SHIPLOG_HOME/test/*.bats" > /dev/null; then
  bats -r "$SHIPLOG_HOME/test"
else
  echo "No tests found at $SHIPLOG_HOME/test/*.bats"
fi
SCRIPT
RUN chmod +x /usr/local/bin/run-tests

ENV ENABLE_SIGNING=${ENABLE_SIGNING}

ENTRYPOINT ["/usr/local/bin/run-tests"]
