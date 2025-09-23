# syntax=docker/dockerfile:1

ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE} AS base

ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=$DEBIAN_FRONTEND \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       jq \
       bats \
       gnupg \
       curl \
       ca-certificates \
       shellcheck \
    && rm -rf /var/lib/apt/lists/*


# ---------------------------------------------------------------------------
# devcontainer stage
# ---------------------------------------------------------------------------
FROM base AS devcontainer

ARG DEVCONTAINER_USER=vscode
RUN if ! id "$DEVCONTAINER_USER" >/dev/null 2>&1; then \
      useradd -ms /bin/bash "$DEVCONTAINER_USER"; \
    fi
USER "$DEVCONTAINER_USER"
WORKDIR /workspaces/shiplog
CMD ["bash"]

# ---------------------------------------------------------------------------
# test runner image (default)
# ---------------------------------------------------------------------------
FROM base AS test
ARG ENABLE_SIGNING=false
ENV ENABLE_SIGNING=$ENABLE_SIGNING

WORKDIR /workspace
COPY . /workspace

ENV SHIPLOG_HOME=/workspace \
    SHIPLOG_LIB_DIR=/workspace/lib \
    SHIPLOG_BOSUN_BIN=/workspace/scripts/bosun \
    PATH=/workspace/bin:$PATH

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
export PATH="$SHIPLOG_HOME/bin:$PATH"
export SHIPLOG_BOSUN_BIN="${SHIPLOG_BOSUN_BIN:-$SHIPLOG_HOME/scripts/bosun}"
export SHIPLOG_REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}
export SHIPLOG_NOTES_REF=${SHIPLOG_NOTES_REF:-refs/_shiplog/notes/logs}

if [ "${ENABLE_SIGNING:-false}" = "true" ]; then
  if ! command -v gpg >/dev/null; then
    echo "gnupg missing" >&2
    exit 1
  fi
  if ! gpg --list-secret-keys --with-colons | grep -q "^sec:"; then
    echo "Generating throw-away GPG key"
    mkdir -p ~/.gnupg
    chmod 700 ~/.gnupg
    printf "allow-loopback-pinentry\n" > ~/.gnupg/gpg-agent.conf
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

echo "Setting up throw-away repo"
TMPREPO="$(mktemp -d)"
cd "$TMPREPO"
git init -q
git config user.name  "$TEST_AUTHOR_NAME"
git config user.email "$TEST_AUTHOR_EMAIL"
git commit --allow-empty -m init >/dev/null

if [ ! -f "${SHIPLOG_HOME}/bin/git-shiplog" ]; then
  echo "Missing ${SHIPLOG_HOME}/bin/git-shiplog. Mount your project into ${SHIPLOG_HOME}." >&2
  exit 1
fi
install -m 0755 "${SHIPLOG_HOME}/bin/git-shiplog" /usr/local/bin/git-shiplog

git config --add remote.origin.fetch "+${SHIPLOG_REF_ROOT}/*:${SHIPLOG_REF_ROOT}/*" || true
git config --add remote.origin.push  "${SHIPLOG_REF_ROOT}/*:${SHIPLOG_REF_ROOT}/*"  || true
git config core.logAllRefUpdates true

echo "Running bats tests"
if compgen -G "${SHIPLOG_HOME}/test/*.bats" > /dev/null; then
  bats -r "${SHIPLOG_HOME}/test"
else
  echo "No tests found at ${SHIPLOG_HOME}/test/*.bats"
fi
SCRIPT
RUN chmod +x /usr/local/bin/run-tests

ENTRYPOINT ["/usr/local/bin/run-tests"]
