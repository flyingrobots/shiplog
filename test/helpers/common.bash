#!/usr/bin/env bash

SHIPLOG_PROJECT_ROOT="${SHIPLOG_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SHIPLOG_SANDBOX_REPO="${SHIPLOG_SANDBOX_REPO:-https://github.com/flyingrobots/shiplog-testing-sandbox.git}"
SHIPLOG_SANDBOX_BRANCH="${SHIPLOG_SANDBOX_BRANCH:-main}"
SHIPLOG_TEST_ROOT="${SHIPLOG_TEST_ROOT:-$(pwd)}"

declare -ag SHIPLOG_ORIG_REMOTE_ORDER=()
declare -Ag SHIPLOG_ORIG_REMOTES_CONFIG=()
declare -gi SHIPLOG_CALLER_REPO_CAPTURED=0

shiplog_git_caller() {
  git -c safe.directory="$SHIPLOG_TEST_ROOT" -C "$SHIPLOG_TEST_ROOT" "$@"
}

shiplog_helper_error() {
  echo "ERROR: $*" >&2
  return 1
}

shiplog_restore_exec() {
  local context="$1"
  shift
  local output
  if ! output=$(shiplog_git_caller "$@" 2>&1); then
    local nocasematch_was_disabled=0
    if ! shopt -q nocasematch; then
      shopt -s nocasematch
      nocasematch_was_disabled=1
    fi
    if [[ "$output" =~ read-?only || "$output" =~ permission\ denied || "$output" =~ operation\ not\ permitted ]]; then
      if [ "$nocasematch_was_disabled" -eq 1 ]; then
        shopt -u nocasematch
      fi
      shiplog_helper_error "Skipping remote restore: config is read-only" || true
      shiplog_reset_remote_snapshot_state
      return 1
    fi
    if [ "$nocasematch_was_disabled" -eq 1 ]; then
      shopt -u nocasematch
    fi
    shiplog_helper_error "$context: $output" || true
    return 2
  fi
  return 0
}

shiplog_reset_remote_snapshot_state() {
  SHIPLOG_ORIG_REMOTE_ORDER=()
  unset SHIPLOG_ORIG_REMOTES_CONFIG
  declare -Ag SHIPLOG_ORIG_REMOTES_CONFIG=()
  SHIPLOG_CALLER_REPO_CAPTURED=0
}

shiplog_snapshot_caller_repo_state() {
  local -a order=()
  declare -A config_map=()

  if ! shiplog_git_caller rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    shiplog_helper_error "Caller repository is not a git repository: $SHIPLOG_TEST_ROOT" || return 1
  fi

  local remote_list
  if ! remote_list=$(shiplog_git_caller remote 2>&1); then
    shiplog_helper_error "Failed to list caller remotes: $remote_list" || return 1
  fi

  local remote
  while IFS= read -r remote; do
    [ -n "$remote" ] || continue
    order+=("$remote")
    local escaped config
    escaped=$(printf '%s' "$remote" | sed 's/[\\[\].*^$?+(){}|-]/\\&/g')
    config=$(shiplog_git_caller config --local --get-regexp "^remote\\.${escaped}\\." 2>/dev/null || true)
    config_map["$remote"]="$config"
  done <<<"$remote_list"

  shiplog_reset_remote_snapshot_state
  SHIPLOG_ORIG_REMOTE_ORDER=("${order[@]}")
  for remote in "${SHIPLOG_ORIG_REMOTE_ORDER[@]}"; do
    SHIPLOG_ORIG_REMOTES_CONFIG["$remote"]="${config_map[$remote]}"
  done
  SHIPLOG_CALLER_REPO_CAPTURED=1
  return 0
}

shiplog_restore_caller_remotes() {
  [ "$SHIPLOG_CALLER_REPO_CAPTURED" -eq 1 ] || return 0

  # Test harness override: allows Bats to simulate read-only configs while running
  # as root inside the Docker container. See test/26_remote_restore.bats.
  if [[ "${SHIPLOG_FORCE_REMOTE_RESTORE_SKIP:-0}" = "1" ]]; then
    shiplog_helper_error "Skipping remote restore: config is read-only" || true
    shiplog_reset_remote_snapshot_state
    return 0
  fi

  local remote_list
  if ! remote_list=$(shiplog_git_caller remote 2>&1); then
    shiplog_helper_error "Failed to list caller remotes during restore: $remote_list" || return 1
  fi

  declare -A expected=()
  local remote
  for remote in "${SHIPLOG_ORIG_REMOTE_ORDER[@]}"; do
    expected["$remote"]=1
  done

  local listed rc
  while IFS= read -r listed; do
    [ -n "$listed" ] || continue
    if [[ -z ${expected[$listed]+_} ]]; then
      local removal_output
      if ! removal_output=$(shiplog_git_caller remote remove "$listed" 2>&1); then
        local nocasematch_was_disabled=0
        if ! shopt -q nocasematch; then
          shopt -s nocasematch
          nocasematch_was_disabled=1
        fi
        if [[ "$removal_output" =~ read-?only || "$removal_output" =~ permission\ denied || "$removal_output" =~ operation\ not\ permitted ]]; then
          if [ "$nocasematch_was_disabled" -eq 1 ]; then
            shopt -u nocasematch
          fi
          shiplog_helper_error "Skipping remote restore: config is read-only" || true
          shiplog_reset_remote_snapshot_state
          return 0
        fi
        if [ "$nocasematch_was_disabled" -eq 1 ]; then
          shopt -u nocasematch
        fi
        if [[ "$removal_output" =~ "No such remote" ]]; then
          :
        else
          shiplog_helper_error "Failed to remove unexpected remote \"$listed\": $removal_output" || return 1
        fi
      fi
      shiplog_git_caller config --local --remove-section "remote.$listed" >/dev/null 2>&1 || true
    fi
  done <<<"$remote_list"

  for remote in "${SHIPLOG_ORIG_REMOTE_ORDER[@]}"; do
    local desired="${SHIPLOG_ORIG_REMOTES_CONFIG[$remote]}"
    shiplog_git_caller remote remove "$remote" >/dev/null 2>&1 || true
    shiplog_git_caller config --local --remove-section "remote.$remote" >/dev/null 2>&1 || true

    [ -n "$desired" ] || continue

    local first_url=""
    local -a lines=()
    local line
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      lines+=("$line")
      local key value
      key=${line%% *}
      value=${line#* }
      if [[ "$key" == "remote.$remote.url" && -z "$first_url" ]]; then
        first_url="$value"
      fi
    done <<<"$desired"

    if [ -z "$first_url" ]; then
      shiplog_helper_error "Missing URL while restoring remote \"$remote\"" || return 1
    fi

    shiplog_restore_exec "Failed to re-add remote \"$remote\"" remote add "$remote" "$first_url"
    case $? in
      0) ;;
      1) return 0 ;;
      *) return 1 ;;
    esac

    shiplog_git_caller config --local --unset-all "remote.$remote.fetch" >/dev/null 2>&1 || true
    shiplog_git_caller config --local --unset-all "remote.$remote.pushurl" >/dev/null 2>&1 || true

    local primary_seen=0
    local key value
    for line in "${lines[@]}"; do
      key=${line%% *}
      value=${line#* }
      case "$key" in
        "remote.$remote.url")
          if [ "$value" = "$first_url" ] && [ $primary_seen -eq 0 ]; then
            primary_seen=1
            continue
          fi
          shiplog_restore_exec "Failed to add additional URL for \"$remote\"" remote set-url --add "$remote" "$value"
          case $? in
            0) ;;
            1) return 0 ;;
            *) return 1 ;;
          esac
          ;;
        "remote.$remote.pushurl")
          shiplog_restore_exec "Failed to add pushurl for \"$remote\"" remote set-url --push --add "$remote" "$value"
          case $? in
            0) ;;
            1) return 0 ;;
            *) return 1 ;;
          esac
          ;;
        "remote.$remote.fetch")
          shiplog_restore_exec "Failed to restore fetch spec for \"$remote\"" config --local --add "remote.$remote.fetch" "$value"
          case $? in
            0) ;;
            1) return 0 ;;
            *) return 1 ;;
          esac
          ;;
        *)
          shiplog_restore_exec "Failed to restore $key" config --local --add "$key" "$value"
          case $? in
            0) ;;
            1) return 0 ;;
            *) return 1 ;;
          esac
          ;;
      esac
    done
  done

  shiplog_reset_remote_snapshot_state
  return 0
}

shiplog_install_cli() {
  local project_home="${SHIPLOG_HOME:-$SHIPLOG_PROJECT_ROOT}"

  if [[ ! -f "${project_home}/bin/git-shiplog" ]]; then
    echo "ERROR: Source file ${project_home}/bin/git-shiplog does not exist!" >&2
    return 1
  fi

  if [[ ! -x "${project_home}/bin/git-shiplog" ]]; then
    echo "ERROR: Source file ${project_home}/bin/git-shiplog is not executable!" >&2
    return 1
  fi

  local target_dir="/usr/local/bin"
  if [ ! -w "$target_dir" ]; then
    target_dir="$HOME/.local/bin"
    mkdir -p "$target_dir"
  fi

  case ":$PATH:" in
    *":$target_dir:"*) ;;
    *) export PATH="$target_dir:$PATH" ;;
  esac

  if ! install -m 0755 "${project_home}/bin/git-shiplog" "$target_dir/git-shiplog"; then
    echo "ERROR: Failed to install git-shiplog binary!" >&2
    return 1
  fi

  export SHIPLOG_HOME="$project_home"
  case ":$PATH:" in
    *":$project_home/bin:"*) ;;
    *) export PATH="$project_home/bin:$PATH" ;;
  esac
}

shiplog_clone_sandbox_repo() {
  local dest="$1"
  git clone -q "$SHIPLOG_SANDBOX_REPO" "$dest"
  (
    cd "$dest"
    git fetch -q origin "$SHIPLOG_SANDBOX_BRANCH"
    git checkout -q "$SHIPLOG_SANDBOX_BRANCH"
    git pull -q --ff-only origin "$SHIPLOG_SANDBOX_BRANCH"
  )
}

shiplog_use_sandbox_repo() {
  local dest
  dest="${1:-}"
  if [[ -z "$dest" ]]; then
    dest="$(mktemp -d)"
  else
    mkdir -p "$dest"
  fi
  if [[ "${SHIPLOG_USE_LOCAL_SANDBOX:-0}" = "1" ]]; then
    # Initialize a local empty repo instead of cloning from network
    cd "$dest" || { echo "ERROR: Failed to cd to $dest" >&2; return 1; }
    git init -q
    # Ensure test identity is set BEFORE making any commits
    git config user.name "Shiplog Tester"
    git config user.email "shiplog-tester@example.com"
    # Create an initial commit to avoid detached HEAD states in some flows
    : > .gitkeep
    git add .gitkeep
    git commit -q -m "init"
  else
    shiplog_clone_sandbox_repo "$dest"
    cd "$dest" || { echo "ERROR: Failed to cd to $dest" >&2; return 1; }
  fi
  export SHIPLOG_SANDBOX_DIR="$dest"
  # Ensure test identity is set (redundant when local sandbox path is used)
  git config user.name "Shiplog Tester"
  git config user.email "shiplog-tester@example.com"
  # Safety: remove upstream origin to prevent accidental network pushes
  git remote remove origin >/dev/null 2>&1 || true
}

shiplog_cleanup_sandbox_repo() {
  cd "$SHIPLOG_TEST_ROOT"
  if [[ -n "${SHIPLOG_SANDBOX_DIR:-}" && -d "$SHIPLOG_SANDBOX_DIR" ]]; then
    rm -rf "$SHIPLOG_SANDBOX_DIR"
    unset SHIPLOG_SANDBOX_DIR
  fi
}

shiplog_setup_test_signing() {
  local method="${SHIPLOG_TEST_SIGN_METHOD:-ssh}"
  if [[ "$method" = "ssh" ]]; then
    local tmpdir
    tmpdir=$(mktemp -d)
    if ! ssh-keygen -q -t ed25519 -N '' -f "$tmpdir/id_ed25519"; then
      echo "ERROR: Failed to generate SSH key" >&2
      rm -rf "$tmpdir"
      return 1
    fi
    git config gpg.format ssh
    git config user.signingkey "$tmpdir/id_ed25519"
    # TODO: Track tmpdir for cleanup
  else
    export GNUPGHOME="$(mktemp -d)"
    printf '%s\n' allow-loopback-pinentry >"$GNUPGHOME/gpg-agent.conf"
    printf '%s\n' pinentry-mode\ loopback >"$GNUPGHOME/gpg.conf"
    gpgconf --kill gpg-agent >/dev/null 2>&1 || true
    if ! gpg --batch --pinentry-mode loopback --passphrase '' \
       --quick-gen-key "Shiplog Tester <shiplog-tester@example.com>" ed25519 sign 1y >/dev/null 2>&1; then
      echo "ERROR: Failed to generate GPG key" >&2
      return 1
    fi
    local fpr
    fpr=$(gpg --batch --list-secret-keys --with-colons | awk -F: '/^fpr:/{print $10; exit}')
    if [[ -n "$fpr" ]]; then
      git config gpg.format openpgp
      git config user.signingkey "$fpr"
      export GPG_TTY="${GPG_TTY:-$(tty 2>/dev/null || echo /dev/null)}"
    fi
  fi
}

shiplog_bootstrap_trust() {
  local with_signers="${1:-1}"
  mkdir -p .shiplog
  cat > .shiplog/trust.json <<'JSON'
{
  "version": 1,
  "id": "shiplog-trust-root",
  "threshold": 1,
  "maintainers": [
    {
      "name": "Shiplog Tester",
      "email": "shiplog-tester@example.com",
      "pgp_fpr": "TESTFINGERPRINT",
      "role": "root",
      "revoked": false
    }
  ]
}
JSON

  if [[ "$with_signers" -eq 1 ]]; then
    cat > .shiplog/allowed_signers <<'EOF'
shiplog-tester@example.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITESTKEYSHIPLOGTESTER
EOF
  else
    rm -f .shiplog/allowed_signers
  fi

  local oid_trust tree
  oid_trust=$(git hash-object -w .shiplog/trust.json)
  if [[ "$with_signers" -eq 1 ]]; then
    local oid_sigs
    oid_sigs=$(git hash-object -w .shiplog/allowed_signers)
    tree=$(printf "100644 blob %s\ttrust.json\n100644 blob %s\tallowed_signers\n" "$oid_trust" "$oid_sigs" | git mktree)
  else
    tree=$(printf "100644 blob %s\ttrust.json\n" "$oid_trust" | git mktree)
  fi

  local commit
  commit=$(echo "shiplog: trust root v1 (GENESIS)" |
    GIT_AUTHOR_NAME="Trust Init" \
    GIT_AUTHOR_EMAIL="trust@local" \
    git commit-tree "$tree")

  git update-ref refs/_shiplog/trust/root "$commit"
}

shiplog_write_local_policy() {
  mkdir -p .shiplog
  cat > .shiplog/policy.json <<'JSON'
{
  "version": "1.0.0",
  "require_signed": false,
  "authors": {
    "default_allowlist": [
      "shiplog-tester@example.com"
    ]
  }
}
JSON
}

shiplog_bootstrap_policy_ref() {
  shiplog_write_local_policy
  local policy_blob shiplog_tree tree parent commit
  policy_blob=$(git hash-object -w .shiplog/policy.json)
  shiplog_tree=$(printf '100644 blob %s\tpolicy.json\n' "$policy_blob" | git mktree)
  tree=$(printf '040000 tree %s\t.shiplog\n' "$shiplog_tree" | git mktree)
  parent=$(git rev-parse --verify refs/_shiplog/policy/current 2>/dev/null || true)
  if [[ -n "$parent" ]]; then
    commit=$(GIT_AUTHOR_NAME="Shiplog Policy" GIT_AUTHOR_EMAIL="policy@shiplog.test" \
      GIT_COMMITTER_NAME="Shiplog Policy" GIT_COMMITTER_EMAIL="policy@shiplog.test" \
      git commit-tree "$tree" -p "$parent" -m "shiplog: policy update")
    git update-ref refs/_shiplog/policy/current "$commit" "$parent"
  else
    commit=$(GIT_AUTHOR_NAME="Shiplog Policy" GIT_AUTHOR_EMAIL="policy@shiplog.test" \
      GIT_COMMITTER_NAME="Shiplog Policy" GIT_COMMITTER_EMAIL="policy@shiplog.test" \
      git commit-tree "$tree" -m "shiplog: policy init")
    git update-ref refs/_shiplog/policy/current "$commit"
  fi
}

shiplog_standard_setup() {
  shiplog_install_cli
  shiplog_use_sandbox_repo
  shiplog_bootstrap_trust
  shiplog_write_local_policy
  git config --unset-all shiplog.policy.allowedAuthors >/dev/null 2>&1 || true
  git config --unset-all shiplog.policy.requireSigned >/dev/null 2>&1 || true
  git config --unset-all shiplog.policy.allowedSignersFile >/dev/null 2>&1 || true
  git config --unset-all shiplog.policy.allowedAuthors >/dev/null 2>&1 || true
  git config user.name "Shiplog Tester"
  git config user.email "shiplog-tester@example.com"
  export SHIPLOG_HOME="$SHIPLOG_PROJECT_ROOT"
  case ":$PATH:" in
    *":$SHIPLOG_PROJECT_ROOT/bin:"*) ;;
    *) export PATH="$SHIPLOG_PROJECT_ROOT/bin:$PATH" ;;
  esac
  git shiplog trust sync >/dev/null
}

shiplog_standard_teardown() {
  shiplog_cleanup_sandbox_repo
}

# --- Test-only helpers for robust SSH principal acceptance ---
# Write an allowed_signers file for the current repo's signing key that
# includes both the exact user.email principal and portable fallbacks.
# Usage: shiplog_write_allowed_signers_for_signing_key <output-path>
shiplog_write_allowed_signers_for_signing_key() {
  local out="${1:-.shiplog/allowed_signers}"
  local priv pub email domain
  # Ensure destination directory exists
  local out_dir
  out_dir="$(dirname "$out")"
  if ! mkdir -p "$out_dir"; then
    echo "ERROR: failed to create directory for allowed_signers: $out_dir" >&2
    return 1
  fi
  priv="$(git config user.signingkey)"
  if [[ -z "$priv" ]]; then
    echo "ERROR: user.signingkey not configured" >&2
    return 1
  fi
  if ! pub="$(ssh-keygen -y -f "$priv" 2>/dev/null)"; then
    echo "ERROR: failed to derive public key from $priv" >&2
    return 1
  fi
  email="$(git config user.email)"
  domain="${email##*@}"
  : > "$out"
  # 1) Exact email principal
  printf '%s %s\n' "$email" "$pub" >>"$out"
  # 2) Domain wildcard (covers distros that vary principal formatting but keep email domain)
  if [[ -n "$domain" && "$domain" != "$email" ]]; then
    printf '*@%s %s\n' "$domain" "$pub" >>"$out"
  fi
  # 3) Ultimate wildcard as last resort (test-only)
  printf '* %s\n' "$pub" >>"$out"
}
