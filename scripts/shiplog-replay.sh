#!/usr/bin/env bash
set -euo pipefail

# shiplog-replay.sh — experimental log replay for Shiplog journals
#
# Replays a sequence of Shiplog entries from a journal, printing each entry's
# summary and (optionally) attached log notes. Timing is simulated using the
# recorded run duration when present, with a configurable speed multiplier.
#
# Usage:
#   scripts/shiplog-replay.sh [--env ENV] [--from SHA] [--to SHA] \
#     [--count N] [--speed X] [--no-notes] [--compact] [--step]
#
# Defaults:
#   --env ${SHIPLOG_ENV:-prod}
#   --count 5
#   --speed 1.0  (use 0 for fastest replay without sleeps)
#
# Notes:
#   - This is a read-only helper. It does not modify refs.
#   - Attached notes are printed as saved; they are not timestamped per line.
#     When a run duration is present, lines are paced uniformly across it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REF_ROOT="${SHIPLOG_REF_ROOT:-refs/_shiplog}"
NOTES_REF="${SHIPLOG_NOTES_REF:-refs/_shiplog/notes/logs}"
ENV_NAME="${SHIPLOG_ENV:-prod}"
DEPLOY_ID=""
FROM_SHA=""
TO_SHA=""
COUNT=5
SPEED=1.0
PRINT_NOTES=1
COMPACT=0
STEP=0

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing dependency: $1" >&2; exit 1; }; }
need git
need jq

while [ $# -gt 0 ]; do
  case "$1" in
    --env) shift; ENV_NAME="${1:-$ENV_NAME}"; shift; continue ;;
    --env=*) ENV_NAME="${1#*=}"; shift; continue ;;
    --from) shift; FROM_SHA="${1:-}"; shift; continue ;;
    --from=*) FROM_SHA="${1#*=}"; shift; continue ;;
    --to) shift; TO_SHA="${1:-}"; shift; continue ;;
    --to=*) TO_SHA="${1#*=}"; shift; continue ;;
    --count) shift; COUNT="${1:-$COUNT}"; shift; continue ;;
    --count=*) COUNT="${1#*=}"; shift; continue ;;
    --speed) shift; SPEED="${1:-$SPEED}"; shift; continue ;;
    --speed=*) SPEED="${1#*=}"; shift; continue ;;
    --deployment) shift; DEPLOY_ID="${1:-}"; shift; continue ;;
    --deployment=*) DEPLOY_ID="${1#*=}"; shift; continue ;;
    --ticket) shift; DEPLOY_ID="${1:-}"; shift; continue ;;
    --ticket=*) DEPLOY_ID="${1#*=}"; shift; continue ;;
    --no-notes) PRINT_NOTES=0; shift; continue ;;
    --compact) COMPACT=1; shift; continue ;;
    --step) STEP=1; shift; continue ;;
    --help|-h)
      cat <<EOF
Usage: scripts/shiplog-replay.sh [OPTIONS]

Options:
  --env ENV           Journal environment (default: ${SHIPLOG_ENV:-prod})
  --from SHA          Start at this entry (inclusive). If omitted, start from tip.
  --to SHA            Stop at (and include) this entry.
  --count N           Limit number of entries (default: 5)
  --speed X           Speed multiplier (default: 1.0). 0 = fastest (no sleeps)
  --no-notes          Do not print attached notes (logs)
  --compact           Print summary lines only (no JSON trailer)
  --step              Pause for Enter between entries instead of sleeping
EOF
      exit 0
      ;;
    --) shift; break ;;
    *) echo "❌ Unknown option: $1" >&2; exit 1 ;;
  esac
done

JOURNAL_REF="$REF_ROOT/journal/$ENV_NAME"
git rev-parse --verify "$JOURNAL_REF" >/dev/null 2>&1 || { echo "❌ No journal at $JOURNAL_REF" >&2; exit 1; }

# Build rev-list range
RANGE=("$JOURNAL_REF")
[ -n "$TO_SHA" ] && RANGE=("$TO_SHA".."$JOURNAL_REF")
[ -n "$FROM_SHA" ] && RANGE+=("^$FROM_SHA")

if [ -n "$DEPLOY_ID" ]; then
  mapfile -t COMMITS < <(
    git shiplog export-json "$ENV_NAME" \
      | jq -r --arg id "$DEPLOY_ID" 'select((.deployment.id // "") == $id or (.why.ticket // "") == $id) | .commit' \
      | tac
  )
else
  mapfile -t COMMITS < <(git rev-list --max-count="$COUNT" "${RANGE[@]}")
fi
[ "${#COMMITS[@]}" -gt 0 ] || { echo "ℹ️ No entries to replay"; exit 0; }

render_entry() {
  local c="$1"
  local body json
  body="$(git show -s --format=%B "$c")"
  json="$(awk 'BEGIN{p=0} /^---$/{p=1;next} p{print}' <<<"$body")"

  local service env status ts seq author repo_head dur_s started finished
  service="$(jq -r '.what.service // "?"' <<<"$json" 2>/dev/null || echo "?")"
  env="$(jq -r '.env // "?"' <<<"$json" 2>/dev/null || echo "?")"
  status="$(jq -r '.status // "?"' <<<"$json" 2>/dev/null || echo "?")"
  ts="$(jq -r '.ts // "?"' <<<"$json" 2>/dev/null || echo "?")"
  seq="$(jq -r '.seq // "?"' <<<"$json" 2>/dev/null || echo "?")"
  author="$(jq -r '.who.email // "?"' <<<"$json" 2>/dev/null || echo "?")"
  repo_head="$(jq -r '.repo_head // "?"' <<<"$json" 2>/dev/null || echo "?")"
  dur_s=$(jq -r '(.run.duration_s // .when.dur_s // 0)' <<<"$json" 2>/dev/null || echo 0)
  started="$(jq -r '(.run.started_at // .when.start_ts // "")' <<<"$json" 2>/dev/null || echo "")"
  finished="$(jq -r '(.run.finished_at // .when.end_ts // "")' <<<"$json" 2>/dev/null || echo "")"

  local header
  header=$(cat <<EOF
▶ ${service} → ${env}  |  status=${status}  seq=${seq}  ts=${ts}
   author=${author}  repo=${repo_head}
EOF
)
  printf '%s\n' "$header"

  if [ "$COMPACT" -eq 0 ]; then
    printf '%s\n' "$json" | jq -C -S . || printf '%s\n' "$json"
  fi

  if [ "$PRINT_NOTES" -eq 1 ]; then
    if git notes --ref="$NOTES_REF" show "$c" >/dev/null 2>&1; then
      echo "--- log (notes) ---"
      local lines
      if [ "$SPEED" = "0" ]; then
        git notes --ref="$NOTES_REF" show "$c"
      else
        # Pace uniformly across duration (fallback to minimal pacing)
        local total_lines sleep_per=0.03
        mapfile -t lines < <(git notes --ref="$NOTES_REF" show "$c")
        total_lines=${#lines[@]}
        if [ "$total_lines" -gt 0 ] && [ "$dur_s" -gt 0 ]; then
          # Distribute sleeps across lines with multiplier
          sleep_per=$(awk -v d="$dur_s" -v n="$total_lines" -v s="$SPEED" 'BEGIN{ if (s<=0) s=1; sp=(d/n)/s; if(sp<0.01) sp=0.01; print sp }')
        fi
        for ln in "${lines[@]}"; do
          printf '%s\n' "$ln"
          sleep "$sleep_per"
        done
      fi
      echo "--- end log ---"
    fi
  fi

  # Wait between entries: either step or approximate gap by duration
  if [ "$STEP" -eq 1 ]; then
    read -r -p "[enter to continue]" _ || true
  else
    if [ "$SPEED" != "0" ] && [ "$dur_s" -gt 0 ]; then
      local gap
      gap=$(awk -v d="$dur_s" -v s="$SPEED" 'BEGIN{ if (s<=0) s=1; g=d/s; if(g>3) g=3; print g }')
      sleep "$gap"
    fi
  fi
}

for c in "${COMMITS[@]}"; do
  render_entry "$c"
  echo
done

echo "✅ replay complete (${#COMMITS[@]} entries)"
