# Common utility functions for Shiplog CLI

is_boring() {
  [ "${SHIPLOG_BORING:-0}" = "1" ]
}

die() {
  echo "❌ $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

fmt_ts() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

shiplog_prompt_input() {
  local placeholder="$1"
  local env_var="$2"
  local fallback="${3:-}"
  local value="${!env_var:-$fallback}"
  if is_boring; then
    printf '%s\n' "$value"
  else
    "$GUM" input --placeholder "$placeholder" --value "$value"
  fi
}

shiplog_prompt_choice() {
  local header="$1"
  local env_var="$2"
  shift 2 || true
  local options=("$@")
  local fallback="${options[0]:-}"
  local value="${!env_var:-$fallback}"
  if [ -z "$value" ]; then
    value="$fallback"
  fi
  if is_boring; then
    printf '%s\n' "$value"
  else
    if [ -n "$value" ]; then
      GUM_CHOICE="$value" "$GUM" choose "${options[@]}" --header "$header"
    else
      "$GUM" choose "${options[@]}" --header "$header"
    fi
  fi
}

shiplog_confirm() {
  local prompt="$1"
  if is_boring || [ "${SHIPLOG_ASSUME_YES:-0}" = "1" ]; then
    return 0
  fi
  "$GUM" confirm "$prompt"
}
