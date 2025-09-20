#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHIPLOG_HOME="${SHIPLOG_HOME:-$SCRIPT_DIR}"
LIB_DIR="${SHIPLOG_LIB_DIR:-$SHIPLOG_HOME/lib}"

# -------- Config Defaults --------
REF_ROOT="${SHIPLOG_REF_ROOT:-refs/_shiplog}"
NOTES_REF="${SHIPLOG_NOTES_REF:-refs/_shiplog/notes/logs}"
DEFAULT_ENV="${SHIPLOG_ENV:-prod}"
AUTHOR_ALLOWLIST="${SHIPLOG_AUTHORS:-}"
ALLOWED_SIGNERS_FILE="${SHIPLOG_ALLOWED_SIGNERS:-.git/allowed_signers}"
GUM=${GUM:-gum}

POLICY_REF_DEFAULT="refs/_shiplog/policy/current"
POLICY_REF="${SHIPLOG_POLICY_REF:-$POLICY_REF_DEFAULT}"

SHIPLOG_POLICY_INITIALIZED=0
POLICY_SOURCE=""
POLICY_REQUIRE_SIGNED=""
POLICY_ALLOWED_SIGNERS_FILE=""
POLICY_ALLOWED_AUTHORS=""
POLICY_NOTES_REF=""
POLICY_JOURNALS_PREFIX=""
POLICY_ANCHORS_PREFIX=""

SHIPLOG_SIGN_EFFECTIVE=""
ALLOWED_AUTHORS_EFFECTIVE=""
SIGNERS_FILE_EFFECTIVE=""

# -------- Source Library Functions --------
[ -d "$LIB_DIR" ] || { echo "❌ shiplog: unable to locate lib dir ($LIB_DIR)" >&2; exit 1; }

source "$LIB_DIR/common.sh"
source "$LIB_DIR/policy.sh"
source "$LIB_DIR/git.sh"
source "$LIB_DIR/commands.sh"

need git
need "$GUM"
need yq

export GIT_ALLOW_REFNAME_COMPONENTS_STARTING_WITH_DOT=1

run_command "$@"
