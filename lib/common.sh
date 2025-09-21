# Common utility functions for Shiplog CLI

is_boring() {
  case "${SHIPLOG_BORING:-0}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
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

escape_json_string() {
  local input="$1" output=""
  if command -v python3 >/dev/null 2>&1; then
    output=$(python3 - "$input" <<'PY' 2>/dev/null || true)
import json, sys
print(json.dumps(sys.argv[1]))
PY
  elif command -v python >/dev/null 2>&1; then
    output=$(python - "$input" <<'PY' 2>/dev/null || true)
import json, sys
print(json.dumps(sys.argv[1]))
PY
  elif command -v jq >/dev/null 2>&1; then
    output=$(printf '%s' "$input" | jq -Rs . 2>/dev/null || true)
  fi

  if [ -n "$output" ]; then
    printf '%s' "$output"
    return 0
  fi

  local fallback
  fallback=$(printf '%s' "$input" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\r/\\r/g; s/\t/\\t/g; s/\f/\\f/g; s/\b/\\b/g; s/\n/\\n/g')
  printf '"%s"' "$fallback"
}

shiplog_prompt_input() {
  [ $# -ge 2 ] || die "shiplog_prompt_input requires at least 2 arguments"
  [ -n "${GUM:-}" ] || die "GUM variable not set"
  need gum
  local placeholder="$1"
  local env_var="$2"
  local fallback="${3:-}"
  
  # Validate env_var is a valid variable name
  case "$env_var" in
    [!a-zA-Z_]*|*[!a-zA-Z0-9_]*) die "Invalid environment variable name: $env_var" ;;
  esac
  
  local value="${!env_var:-$fallback}"
  if is_boring; then
    printf '%s\n' "$value"
  else
    local result
    result=$("$GUM" input --placeholder "$placeholder" --value "$value")
    printf '%s\n' "$result"
    local escaped_placeholder escaped_result
    escaped_placeholder=$(escape_json_string "$placeholder")
    escaped_result=$(escape_json_string "$result")
    "$GUM" log --structured --time "rfc822" --level info "{\"prompt\":$escaped_placeholder,\"value\":$escaped_result}" >&2
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
    local escaped_header escaped_result
    escaped_header=$(escape_json_string "$header")
    escaped_result=$(escape_json_string "$result")
    "$GUM" log --structured --time "rfc822" --level info "{\"prompt\":$escaped_header,\"value\":$escaped_result}" >&2
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
  local escaped_prompt
  escaped_prompt=$(escape_json_string "$prompt")
  "$GUM" log --structured --time "rfc822" --level info "{\"confirmation\":$escaped_prompt,\"value\":null}" >&2
  if "$GUM" confirm "$prompt"; then
    "$GUM" log --structured --time "rfc822" --level info "{\"confirmation\":$escaped_prompt,\"value\":true}" >&2
    return 0
  fi
  "$GUM" log --structured --time "rfc822" --level info "{\"confirmation\":$escaped_prompt,\"value\":false}" >&2
  return 1
}
