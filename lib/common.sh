# shellcheck shell=bash
# Common utility functions for Shiplog CLI

is_boring() {
  case "${SHIPLOG_BORING:-0}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

# Summarize a multi-line stderr blob into a compact, user-friendly line.
# Prints one or two trimmed lines; appends a (+N more lines) suffix when long.
shiplog_summarize_error() {
  local raw_input="${1:-}"
  local first_line="" second_line="" trimmed current extra=0 total=0
  # Normalize CRLF and iterate non-empty lines
  raw_input=${raw_input//$'\r'/}
  while IFS= read -r current; do
    # Skip all-whitespace lines
    case "$current" in *[![:space:]]*) ;; *) continue ;; esac
    total=$((total+1))
    trimmed=$(printf '%s' "$current" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    case "$total" in
      1) first_line="$trimmed" ;;
      2) second_line="$trimmed" ;;
      *) extra=$((extra+1)) ;;
    esac
  done <<<"$raw_input"
  case "$total" in
    0) printf '' ;;
    1) printf '%s' "$first_line" ;;
    2) printf '%s; %s' "$first_line" "$second_line" ;;
    *) printf '%s; %s; (+%d more lines)' "$first_line" "$second_line" "$extra" ;;
  esac
}

# Build confirmation glyphs for successful operations.
# Usage: shiplog_confirm_glyphs <has_anchor:0|1> [status]
# - status: success|error_note (default: success)
shiplog_confirm_glyphs() {
  local has_anchor="${1:-0}"
  local status="${2:-success}"
  local base="🚢🪵"
  local tail=""
  case "$status" in
    success)
      if [ "$has_anchor" = "1" ]; then tail="⚓️"; else tail="✅"; fi ;;
    error_note)
      tail="❌" ;;
    *) : ;;
  esac
  printf '%s%s' "$base" "$tail"
}

die() {
  echo "❌ $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

shiplog_version() {
  if [ -n "${SHIPLOG_VERSION:-}" ]; then
    printf '%s' "$SHIPLOG_VERSION"
    return
  fi

  local repo
  repo="${SHIPLOG_HOME:-$(pwd)}"
  if git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local desc
    desc=$(git -C "$repo" describe --tags --always 2>/dev/null || true)
    if [ -n "$desc" ]; then
      printf '%s' "$desc"
      return
    fi
    desc=$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || true)
    if [ -n "$desc" ]; then
      printf '%s' "$desc"
      return
    fi
  fi

  printf '%s' "unknown"
}

shiplog_bosun_bin() {
  printf '%s' "${SHIPLOG_BOSUN_BIN:-bosun}"
}

shiplog_have_bosun() {
  command -v "$(shiplog_bosun_bin)" >/dev/null 2>&1
}

shiplog_require_bosun() {
  shiplog_have_bosun || die "Missing dependency: $(shiplog_bosun_bin)"
}

shiplog_can_use_bosun() {
  if is_boring; then
    return 1
  fi
  shiplog_have_bosun
}

shiplog_remote_name() {
  if [ -n "${SHIPLOG_REMOTE:-}" ]; then
    printf '%s' "$SHIPLOG_REMOTE"
    return
  fi
  local cfg
  cfg=$(git config shiplog.remote 2>/dev/null || true)
  if [ -n "$cfg" ]; then
    printf '%s' "$cfg"
    return
  fi
  printf '%s' "origin"
}

shiplog_is_dry_run() {
  case "${SHIPLOG_DRY_RUN:-0}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

shiplog_dry_run_notice() {
  local message="${1:-}"
  if [ -z "$message" ]; then
    message="Dry-run: no changes performed"
  fi
  if shiplog_can_use_bosun; then
    local bosun
    bosun=$(shiplog_bosun_bin)
    "$bosun" style --title "Dry Run" -- "$message"
  else
    printf 'ℹ️ dry-run: %s\n' "$message"
  fi
}

shiplog_log_structured() {
  printf '%s\n' "$1" >&2
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
  printf '{"%s":%s,"value":%s}\n' "$field" "$escaped_prompt" "$escaped_result" >&2
}

shiplog_prompt_input() {
  [ $# -ge 2 ] || die "shiplog_prompt_input requires at least 2 arguments"
  local placeholder="$1"
  local env_var="$2"
  local fallback="${3:-}"

  _validate_env_var_name "$env_var"

  local value="${!env_var:-$fallback}"
  if is_boring; then
    printf '%s\n' "$value"
  else
    local result=""
    if shiplog_have_bosun; then
      local bosun err tmp rc
      bosun=$(shiplog_bosun_bin)
      tmp=$(mktemp)
      result=$("$bosun" input --placeholder "$placeholder" --value "$value" 2>"$tmp" || true)
      rc=$?
      if [ $rc -eq 0 ]; then
        printf '%s\n' "$result"
        _log_prompt_interaction prompt "$placeholder" "$result"
        return
      else
        err=$(shiplog_summarize_error "$(cat "$tmp" 2>/dev/null || true)")
        [ -n "${SHIPLOG_PROMPT_UI_WARNED:-}" ] || {
          [ -n "$err" ] && printf '⚠️ shiplog: bosun prompt failed; falling back to text (%s)\n' "$err" >&2 || printf '⚠️ shiplog: bosun prompt failed; falling back to text\n' >&2
          SHIPLOG_PROMPT_UI_WARNED=1
        }
      fi
      rm -f "$tmp" 2>/dev/null || true
    fi
    # Fallback to POSIX prompt
    printf '%s ' "$placeholder" >&2
    IFS= read -r result || result="$value"
    [ -n "$result" ] || result="$value"
    printf '%s\n' "$result"
    _log_prompt_interaction prompt "$placeholder" "$result"
  fi
}

shiplog_prompt_choice() {
  [ $# -ge 3 ] || die "shiplog_prompt_choice requires header, env_var, and at least one option"
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
    local result=""
    if shiplog_have_bosun; then
      local bosun tmp rc err
      bosun=$(shiplog_bosun_bin)
      tmp=$(mktemp)
      if [ -n "$value" ]; then
        result=$("$bosun" choose --header "$header" --default "$value" "${options[@]}" 2>"$tmp" || true)
      else
        result=$("$bosun" choose --header "$header" "${options[@]}" 2>"$tmp" || true)
      fi
      rc=$?
      if [ $rc -ne 0 ]; then
        err=$(shiplog_summarize_error "$(cat "$tmp" 2>/dev/null || true)")
        [ -n "${SHIPLOG_PROMPT_UI_WARNED:-}" ] || {
          [ -n "$err" ] && printf '⚠️ shiplog: bosun choose failed; falling back to text (%s)\n' "$err" >&2 || printf '⚠️ shiplog: bosun choose failed; falling back to text\n' >&2
          SHIPLOG_PROMPT_UI_WARNED=1
        }
      fi
      rm -f "$tmp" 2>/dev/null || true
    fi
    if [ -z "$result" ]; then
      # Fallback: print options and read a line
      printf '%s [%s] ' "$header" "${options[*]}" >&2
      IFS= read -r result || result="$value"
      [ -n "$result" ] || result="$value"
    fi
    printf '%s\n' "$result"
    _log_prompt_interaction prompt "$header" "$result"
  fi
}

shiplog_confirm() {
  [ $# -ge 1 ] || die "shiplog_confirm requires a prompt argument"
  local prompt="$1"
  if is_boring || [ "${SHIPLOG_ASSUME_YES:-0}" = "1" ]; then
    return 0
  fi
  _log_prompt_interaction confirmation "$prompt" null raw
  if shiplog_have_bosun && "$(shiplog_bosun_bin)" confirm "$prompt"; then
    _log_prompt_interaction confirmation "$prompt" true raw
    return 0
  fi
  # Fallback
  printf '%s [y/N] ' "$prompt" >&2
  local ans
  IFS= read -r ans || ans=""
  case "$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')" in
    y|yes) _log_prompt_interaction confirmation "$prompt" true raw; return 0 ;;
  esac
  _log_prompt_interaction confirmation "$prompt" false raw
  return 1
}
