# shellcheck shell=bash
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
  local input="$1"
  command -v jq >/dev/null 2>&1 || die "shiplog: jq is required for structured logging"
  jq -Rn --arg value "$input" '$value'
}

_validate_env_var_name() {
  local name="$1"
  [ -n "$name" ] || die "Environment variable name cannot be empty"
  if [[ ! "$name" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
    die "Invalid environment variable name: $name (use uppercase letters, digits, underscores)"
  fi
  case "$name" in
    PATH|IFS|HOME|LANG|TZ|PWD|SHELL|USER|LOGNAME)
      die "Refusing to override reserved environment variable: $name"
      ;;
  esac
}

_log_prompt_interaction() {
  local field="$1" prompt="$2" result="$3" mode="${4:-string}"
  local escaped_prompt escaped_result
  escaped_prompt=$(escape_json_string "$prompt")
  case "$mode" in
    raw) escaped_result="$result" ;;
    string) escaped_result=$(escape_json_string "$result") ;;
    *) die "Unknown log mode: $mode" ;;
  esac
  "$GUM" log --structured --time "rfc822" --level info "{\"$field\":$escaped_prompt,\"value\":$escaped_result}" >&2
}

shiplog_prompt_input() {
  [ $# -ge 2 ] || die "shiplog_prompt_input requires at least 2 arguments"
  [ -n "${GUM:-}" ] || die "GUM variable not set"
  need gum
  local placeholder="$1"
  local env_var="$2"
  local fallback="${3:-}"

  _validate_env_var_name "$env_var"

  local value="${!env_var:-$fallback}"
  if is_boring; then
    printf '%s\n' "$value"
  else
    local result
    result=$("$GUM" input --placeholder "$placeholder" --value "$value")
    printf '%s\n' "$result"
    _log_prompt_interaction prompt "$placeholder" "$result"
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
  _validate_env_var_name "$env_var"
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
    _log_prompt_interaction prompt "$header" "$result"
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
  _log_prompt_interaction confirmation "$prompt" null raw
  if "$GUM" confirm "$prompt"; then
    _log_prompt_interaction confirmation "$prompt" true raw
    return 0
  fi
  _log_prompt_interaction confirmation "$prompt" false raw
  return 1
}
