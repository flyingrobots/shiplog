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
  [ $# -ge 2 ] || die "shiplog_prompt_input requires at least 2 arguments"
  [ -n "${GUM:-}" ] || die "GUM variable not set"
  need gum
  local placeholder="$1"
  local env_var="$2"
  local fallback="${3:-}"
  local value="${!env_var:-$fallback}"
  if is_boring; then
    printf '%s\n' "$value"
  else
    local result
    result=$("$GUM" input --placeholder "$placeholder" --value "$value")
    printf '%s\n' "$result"
    # Properly escape JSON values
    local escaped_placeholder escaped_result
    escaped_placeholder=$(printf '%s' "$placeholder" | sed 's/\\/\\\\/g; s/"/\\"/g')
    escaped_result=$(printf '%s' "$result" | sed 's/\\/\\\\/g; s/"/\\"/g')
    "$GUM" log --structured --time "rfc822" --level info "{\"prompt\":\"$escaped_placeholder\",\"value\":\"$escaped_result\"}" >&2
  fi
}

shiplog_prompt_choice() {
  [ $# -ge 3 ] || die "shiplog_prompt_choice requires header, env_var, and at least one option"
  [ -n "${GUM:-}" ] || die "GUM variable not set"
  need gum
  local header="$1"
  local env_var="$2"
  shift 2
  local options=("$@")
  [ ${#options[@]} -gt 0 ] || die "At least one option required"
  local fallback="${options[0]:-}"
  local value="${!env_var:-$fallback}"
  if [ -z "$value" ]; then
    value="$fallback"
  fi
  if is_boring; then
    printf '%s\n' "$value"
  else
    local result
    if [ -n "$value" ]; then
      result=$(GUM_CHOICE="$value" "$GUM" choose --header "$header" "${options[@]}")
    else
      result=$("$GUM" choose --header "$header" "${options[@]}")
    fi
    printf '%s\n' "$result"
    # Properly escape JSON values
    local escaped_header escaped_result
    escaped_header=$(printf '%s' "$header" | sed 's/\\/\\\\/g; s/"/\\"/g')
    escaped_result=$(printf '%s' "$result" | sed 's/\\/\\\\/g; s/"/\\"/g')
    "$GUM" log --structured --time "rfc822" --level info "{\"prompt\":\"$escaped_header\",\"value\":\"$escaped_result\"}" >&2
  fi
}

shiplog_confirm() {
  [ $# -ge 1 ] || die "shiplog_confirm requires a prompt argument"
  [ -n "${GUM:-}" ] || die "GUM variable not set"
  need gum
  local prompt="$1"
  if is_boring || [ "${SHIPLOG_ASSUME_YES:-0}" = "1" ]; then
    return 0
  fi
  if "$GUM" confirm "$prompt"; then
    local escaped_prompt
    escaped_prompt=$(printf '%s' "$prompt" | sed 's/\\/\\\\/g; s/"/\\"/g')
    "$GUM" log --structured --time "rfc822" --level info "{\"confirmation\":\"$escaped_prompt\",\"value\":true}" >&2
    return 0
  fi
  local escaped_prompt  
  escaped_prompt=$(printf '%s' "$prompt" | sed 's/\\/\\\\/g; s/"/\\"/g')
  "$GUM" log --structured --time "rfc822" --level info "{\"confirmation\":\"$escaped_prompt\",\"value\":false}" >&2
  return 1
}
