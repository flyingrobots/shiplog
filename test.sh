#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SHIPLOG_HOME="${SHIPLOG_HOME:-$ROOT_DIR}"
export SHIPLOG_LIB_DIR="${SHIPLOG_LIB_DIR:-$SHIPLOG_HOME/lib}"
export SHIPLOG_REF_ROOT="${SHIPLOG_REF_ROOT:-refs/_shiplog}"
export SHIPLOG_NOTES_REF="${SHIPLOG_NOTES_REF:-refs/_shiplog/notes/logs}"
export PATH="$SHIPLOG_HOME/bin:$PATH"

if ! command -v bats >/dev/null 2>&1; then
  echo "bats is required to run the Shiplog test suite" >&2
  exit 127
fi

TMP_GUM_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_GUM_DIR"' EXIT
cat <<'GUM' > "$TMP_GUM_DIR/gum"
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
if [ $# -gt 0 ]; then
  shift
fi
case "$cmd" in
  input)
    value=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --value)
          shift
          value="${1:-}"
          ;;
        --placeholder|--header|--title|--width|--height|--cursor|--password)
          shift
          ;;
        --)
          shift
          break
          ;;
        *)
          break
          ;;
      esac
      [ $# -gt 0 ] || break
      shift || break
    done
    printf '%s\n' "${GUM_INPUT_OVERRIDE:-$value}"
    ;;
  choose)
    choice=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --*) shift ;;
        *) choice="$1"; break ;;
      esac
    done
    printf '%s\n' "${GUM_CHOICE:-$choice}"
    ;;
  confirm)
    exit 0
    ;;
  spin)
    while [ $# -gt 0 ]; do
      [ "$1" = "--" ] && break
      shift || break
    done
    if [ $# -gt 0 ]; then
      "$@"
    fi
    ;;
  style|log)
    if [ $# -gt 0 ]; then
      printf '%s\n' "$*"
    else
      cat
    fi
    ;;
  table)
    header=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --columns)
          shift
          if [ -n "$header" ]; then
            header+=$'\t'
            header+="${1:-}"
          else
            header="${1:-}"
          fi
          ;;
        --)
          shift
          break
          ;;
        *)
          shift
          ;;
      esac
    done
    if [ -n "$header" ]; then
      printf '%s\n' "$header"
    fi
    if [ $# -gt 0 ]; then
      printf '%s\n' "$*"
    else
      cat
    fi
    ;;
  *)
    if [ $# -gt 0 ]; then
      printf '%s\n' "$*"
    else
      cat
    fi
    ;;
 esac
GUM
chmod +x "$TMP_GUM_DIR/gum"
export GUM="$TMP_GUM_DIR/gum"
export PATH="$TMP_GUM_DIR:$PATH"

bats -r "$SHIPLOG_HOME/test"
