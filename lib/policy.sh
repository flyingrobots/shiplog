# Policy resolution helpers (jq-powered, JSON policy files)

parse_policy_json() {
  local env="$1"
  local src="$2"
  local require_signed
  local signers_file
  local notes_ref
  local journals_prefix
  local anchors_prefix
  local authors

  # Validate jq is available
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq command not found" >&2
    return 1
  fi

  # Validate file is readable
  if [ ! -r "$src" ]; then
    echo "ERROR: Cannot read policy file: $src" >&2
    return 1
  fi

  require_signed=$(jq -r '.require_signed // empty' "$src" 2>/dev/null || echo "")
  signers_file=$(jq -r '.allow_ssh_signers_file // empty' "$src" 2>/dev/null || echo "")
  notes_ref=$(jq -r '.notes_ref // empty' "$src" 2>/dev/null || echo "")
  journals_prefix=$(jq -r '.journals_ref_prefix // empty' "$src" 2>/dev/null || echo "")
  anchors_prefix=$(jq -r '.anchors_ref_prefix // empty' "$src" 2>/dev/null || echo "")

  local authors_default authors_env_default authors_env combined
  authors_default=$(jq -r '(.authors.default_allowlist // [])[]?' "$src" 2>/dev/null || true)
  authors_env_default=$(jq -r '(.authors.env_overrides.default // [])[]?' "$src" 2>/dev/null || true)
  authors_env=$(jq -r --arg env "$env" '(.authors.env_overrides[$env] // [])[]?' "$src" 2>/dev/null || true)
  combined=$(printf '%s\n%s\n%s\n' "$authors_default" "$authors_env_default" "$authors_env" | awk 'NF' | sort -u)
  if [ -n "$combined" ]; then
    authors=$(printf '%s\n' "$combined" | paste -sd' ' -)
  else
    authors=""
  fi

  if [ -n "$require_signed" ]; then
    echo "require_signed=$require_signed"
  fi
  if [ -n "$signers_file" ]; then
    echo "allowed_signers_file=$signers_file"
  fi
  if [ -n "$authors" ]; then
    printf 'authors=%s\n' "$authors"
  fi
  if [ -n "$notes_ref" ]; then
    echo "notes_ref=$notes_ref"
  fi
  if [ -n "$journals_prefix" ]; then
    echo "journals_prefix=$journals_prefix"
  fi
  if [ -n "$anchors_prefix" ]; then
    echo "anchors_prefix=$anchors_prefix"
  fi
}

apply_policy_pairs() {
  POLICY_REQUIRE_SIGNED=""
  POLICY_ALLOWED_SIGNERS_FILE=""
  POLICY_ALLOWED_AUTHORS=""
  POLICY_NOTES_REF=""
  POLICY_JOURNALS_PREFIX=""
  POLICY_ANCHORS_PREFIX=""

  while IFS='=' read -r key value; do
    case "$key" in
      require_signed) POLICY_REQUIRE_SIGNED="$value" ;;
      allowed_signers_file) POLICY_ALLOWED_SIGNERS_FILE="$value" ;;
      authors) POLICY_ALLOWED_AUTHORS="$value" ;;
      notes_ref) POLICY_NOTES_REF="$value" ;;
      journals_prefix) POLICY_JOURNALS_PREFIX="$value" ;;
      anchors_prefix) POLICY_ANCHORS_PREFIX="$value" ;;
    esac
  done
}

load_policy_content() {
  local env="$1"
  local from_ref=0
  local parsed

  if git rev-parse --verify "$POLICY_REF" >/dev/null 2>&1; then
    local tmp
    tmp=$(mktemp)
    if git show "$POLICY_REF:.shiplog/policy.json" 2>/dev/null > "$tmp"; then
      if parsed=$(parse_policy_json "$env" "$tmp"); then
        apply_policy_pairs <<<"$parsed"
        POLICY_SOURCE="policy-ref:$POLICY_REF"
        from_ref=1
        rm -f "$tmp"
        return 0
      fi
    fi
    rm -f "$tmp"
  fi

  if [ -f ".shiplog/policy.json" ]; then
    if parsed=$(parse_policy_json "$env" ".shiplog/policy.json"); then
      apply_policy_pairs <<<"$parsed"
      POLICY_SOURCE="policy-file:.shiplog/policy.json"
      return 0
    fi
  fi

  if [ "$from_ref" -eq 1 ]; then
    return 0
  fi
  return 1
}

resolve_policy() {
  if [ "${SHIPLOG_POLICY_INITIALIZED:-0}" -eq 1 ]; then
    return
  fi
  SHIPLOG_POLICY_INITIALIZED=1

  ALLOWED_AUTHORS_EFFECTIVE="${SHIPLOG_AUTHORS:-}"
  SIGNERS_FILE_EFFECTIVE="${SHIPLOG_ALLOWED_SIGNERS:-$ALLOWED_SIGNERS_FILE}"
  SHIPLOG_SIGN_EFFECTIVE="${SHIPLOG_SIGN:-}"

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    [ -z "$SHIPLOG_SIGN_EFFECTIVE" ] && SHIPLOG_SIGN_EFFECTIVE=1
    return
  fi

  if load_policy_content "$DEFAULT_ENV"; then
    :
  fi

  if [ -n "$POLICY_ALLOWED_AUTHORS" ]; then
    ALLOWED_AUTHORS_EFFECTIVE="$POLICY_ALLOWED_AUTHORS"
  elif authors_cfg=$(git config --get shiplog.policy.allowedAuthors 2>/dev/null); then
    ALLOWED_AUTHORS_EFFECTIVE="$authors_cfg"
    [ -z "$POLICY_SOURCE" ] && POLICY_SOURCE="git-config:shiplog.policy.allowedAuthors"
  fi

  if [ -n "$POLICY_ALLOWED_SIGNERS_FILE" ]; then
    SIGNERS_FILE_EFFECTIVE="$POLICY_ALLOWED_SIGNERS_FILE"
  elif signers_cfg=$(git config --get shiplog.policy.allowedSignersFile 2>/dev/null); then
    SIGNERS_FILE_EFFECTIVE="$signers_cfg"
    [ -z "$POLICY_SOURCE" ] && POLICY_SOURCE="git-config:shiplog.policy.allowedSignersFile"
  fi

  if [ -z "$SIGNERS_FILE_EFFECTIVE" ]; then
    SIGNERS_FILE_EFFECTIVE="$ALLOWED_SIGNERS_FILE"
  fi

  if [ -n "$SIGNERS_FILE_EFFECTIVE" ] && [[ "$SIGNERS_FILE_EFFECTIVE" != /* ]]; then
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
    if [ -n "$repo_root" ]; then
      SIGNERS_FILE_EFFECTIVE="$repo_root/$SIGNERS_FILE_EFFECTIVE"
    fi
  fi

  local sign_mode="${SHIPLOG_SIGN:-}"
  if [ -z "$sign_mode" ]; then
    if [ -n "$POLICY_REQUIRE_SIGNED" ]; then
      sign_mode="$POLICY_REQUIRE_SIGNED"
    else
      sign_mode=$(git config --bool shiplog.policy.requireSigned 2>/dev/null || echo "")
      [ -n "$sign_mode" ] && [ -z "$POLICY_SOURCE" ] && POLICY_SOURCE="git-config:shiplog.policy.requireSigned"
    fi
  fi

  case "$sign_mode" in
    0|false|no|off) SHIPLOG_SIGN_EFFECTIVE=0 ;;
    1|true|yes|on) SHIPLOG_SIGN_EFFECTIVE=1 ;;
    "") SHIPLOG_SIGN_EFFECTIVE=1 ;;
    *) SHIPLOG_SIGN_EFFECTIVE=1 ;;
  esac

  if [ "${SHIPLOG_SIGN_EFFECTIVE:-1}" != "0" ] && [ -n "$SIGNERS_FILE_EFFECTIVE" ]; then
    if [ ! -r "$SIGNERS_FILE_EFFECTIVE" ]; then
      die "shiplog: allowed signers file '$SIGNERS_FILE_EFFECTIVE' not found or unreadable"
    fi
  fi

  if [ -n "$POLICY_NOTES_REF" ]; then
    NOTES_REF="$POLICY_NOTES_REF"
  fi

  if [ -n "${SHIPLOG_AUTHORS:-}" ] && [ -z "$POLICY_SOURCE" ] && [ -n "$ALLOWED_AUTHORS_EFFECTIVE" ]; then
    POLICY_SOURCE="env:SHIPLOG_AUTHORS"
  fi

  if [ -z "$POLICY_SOURCE" ]; then
    POLICY_SOURCE="default"
  fi
}
