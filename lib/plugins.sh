# shellcheck shell=bash
# Plugin support for Shiplog (experimental)

shiplog_plugins_dir() {
  local root="${SHIPLOG_PLUGINS_DIR:-$PWD/.shiplog/plugins}"
  printf '%s' "$root"
}

shiplog_plugins_stage_dir() {
  local stage="$1"
  local base
  base=$(shiplog_plugins_dir)
  printf '%s/%s.d' "$base" "$stage"
}

shiplog_plugins_list() {
  local stage="$1"
  local dir
  dir=$(shiplog_plugins_stage_dir "$stage")
  [ -d "$dir" ] || return 0
  local plugin
  while IFS= read -r -d '' plugin; do
    # ensure canonical path stays inside plugins dir
    local canonical
    canonical=$(cd "$(dirname "$plugin")" 2>/dev/null && pwd -P)
    if [ -z "$canonical" ]; then
      continue
    fi
    case "$canonical/" in
      "$(cd "$(shiplog_plugins_dir)" 2>/dev/null && pwd -P)/"*)
        printf '%s\0' "$plugin"
        ;;
      *)
        printf 'shiplog: ignoring plugin outside plugins dir: %s\n' "$plugin" >&2
        ;;
    esac
  done < <(find "$dir" -maxdepth 1 -type f -perm -u+x -name '*.sh' -print0 2>/dev/null | sort -z)
}

shiplog_plugins_filter() {
  local stage="$1" input="$2"
  local tmp_output
  tmp_output="$input"
  local plugin
  while IFS= read -r -d '' plugin; do
    tmp_output=$(printf '%s' "$tmp_output" | "$plugin" "$stage") || {
      printf 'shiplog: plugin %s failed during stage %s\n' "$plugin" "$stage" >&2
      exit 1
    }
  done < <(shiplog_plugins_list "$stage")
  printf '%s' "$tmp_output"
}
