#!/usr/bin/env bash
set -euo pipefail

# Shiplog pre-commit linters (staged files only)
# Tools: shellcheck, markdownlint-cli2, yamllint
# Fails if issues are found. To bypass missing tool failures, set SHIPLOG_LINT_SKIP_MISSING=1.

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

changed() {
  git diff --cached --name-only --diff-filter=ACM | tr '\n' '\0'
}

mapfile -d '' files < <(changed)
[ ${#files[@]} -gt 0 ] || exit 0

sh_files=()
md_files=()
yml_files=()
for f in "${files[@]}"; do
  case "$f" in
    bin/git-shiplog|contrib/hooks/*|*.sh) sh_files+=("$f") ;;
    *.md) md_files+=("$f") ;;
    *.yml|*.yaml) yml_files+=("$f") ;;
  esac
done

fail_missing() {
  if [ "${SHIPLOG_LINT_SKIP_MISSING:-0}" != "1" ]; then
    echo "Missing required tool: $1" >&2
    exit 1
  else
    echo "Skipping $1 (missing)" >&2
  fi
}

# shellcheck
if [ ${#sh_files[@]} -gt 0 ]; then
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -e SC2034 -S style -s bash "${sh_files[@]}"
  else
    fail_missing shellcheck
  fi
fi

# markdownlint-cli2
if [ ${#md_files[@]} -gt 0 ]; then
  if command -v markdownlint-cli2 >/dev/null 2>&1; then
    markdownlint-cli2 "${md_files[@]}"
  else
    # Try npx fallback if Node present
    if command -v npx >/dev/null 2>&1; then
      npx --yes markdownlint-cli2 "${md_files[@]}"
    else
      fail_missing markdownlint-cli2
    fi
  fi
fi

# yamllint
if [ ${#yml_files[@]} -gt 0 ]; then
  if command -v yamllint >/dev/null 2>&1; then
    yamllint -f standard "${yml_files[@]}"
  else
    fail_missing yamllint
  fi
fi

exit 0

