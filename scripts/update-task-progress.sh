#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_DIR="$ROOT_DIR/docs/tasks"
README_TASKS="$TASK_DIR/README.md"
README_ROOT="$ROOT_DIR/README.md"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
need jq

milestones=( "MVP" "Alpha" "Beta" "v1.0.0" )

# Per-milestone counters (portable across old bash without assoc arrays)
done_weight_MVP=0; total_weight_MVP=0; done_count_MVP=0; total_count_MVP=0
done_weight_Alpha=0; total_weight_Alpha=0; done_count_Alpha=0; total_count_Alpha=0
done_weight_Beta=0; total_weight_Beta=0; done_count_Beta=0; total_count_Beta=0
done_weight_v1=0; total_weight_v1=0; done_count_v1=0; total_count_v1=0

weight_of() {
  case "$1" in
    big) echo 3 ;;
    med) echo 2 ;;
    small) echo 1 ;;
    *) echo 2 ;;
  esac
}

collect() {
  local state="$1"
  local dir="$TASK_DIR/$state"
  [ -d "$dir" ] || return 0
  shopt -s nullglob
  for f in "$dir"/*.md; do
    local json
    json=$(cat "$f")
    local ms est
    ms=$(printf '%s' "$json" | jq -r '.milestone // ""')
    est=$(printf '%s' "$json" | jq -r '.estimate // "med"')
    [ -n "$ms" ] || continue
    local w
    w=$(weight_of "$est")
    case "$ms" in
      MVP)
        total_weight_MVP=$(( total_weight_MVP + w ))
        total_count_MVP=$(( total_count_MVP + 1 ))
        if [ "$state" = "complete" ]; then
          done_weight_MVP=$(( done_weight_MVP + w ))
          done_count_MVP=$(( done_count_MVP + 1 ))
        fi
        ;;
      Alpha)
        total_weight_Alpha=$(( total_weight_Alpha + w ))
        total_count_Alpha=$(( total_count_Alpha + 1 ))
        if [ "$state" = "complete" ]; then
          done_weight_Alpha=$(( done_weight_Alpha + w ))
          done_count_Alpha=$(( done_count_Alpha + 1 ))
        fi
        ;;
      Beta)
        total_weight_Beta=$(( total_weight_Beta + w ))
        total_count_Beta=$(( total_count_Beta + 1 ))
        if [ "$state" = "complete" ]; then
          done_weight_Beta=$(( done_weight_Beta + w ))
          done_count_Beta=$(( done_count_Beta + 1 ))
        fi
        ;;
      v1.0.0)
        total_weight_v1=$(( total_weight_v1 + w ))
        total_count_v1=$(( total_count_v1 + 1 ))
        if [ "$state" = "complete" ]; then
          done_weight_v1=$(( done_weight_v1 + w ))
          done_count_v1=$(( done_count_v1 + 1 ))
        fi
        ;;
    esac
  done
  shopt -u nullglob
}

collect backlog
collect active
collect complete

percent() { # args: done total -> integer percent
  local d="$1" t="$2"
  if [ "$t" -eq 0 ]; then echo 0; return; fi
  echo $(( d * 100 / t ))
}

bar() { # args: pct -> 50-char bar
  local p="$1"
  local width=50
  local filled=$(( p * width / 100 ))
  local empty=$(( width - filled ))
  printf '%*s' "$filled" '' | tr ' ' '█'
  printf '%*s' "$empty" '' | tr ' ' '░'
}

render_pb() { # args: title pct completed total
  local title="$1" pct="$2" comp="$3" tot="$4"
  local bs
  bs=$(bar "$pct")
  printf '#### %s\n' "$title"
  printf '```text\n'
  printf '%s %s%% (%s/%s)\n' "$bs" "$pct" "$comp" "$tot"
  printf '|••••|••••|••••|••••|••••|••••|••••|••••|••••|••••|\n'
  printf '0   10   20   30   40   50   60   70   80   90  100%%\n'
  printf '```\n'
}

replace_block() { # args: file marker content
  local file="$1" marker="$2" content="$3" tmpc
  tmpc=$(mktemp)
  printf "%s\n" "$content" > "$tmpc"
  awk -v m="$marker" -v cf="$tmpc" '
    BEGIN{inblk=0}
    $0 ~ "<!-- progress bar: " m " -->" {print; while ((getline line < cf) > 0) print line; close(cf); inblk=1; next}
    $0 ~ "<!-- /progress bar: " m " -->" {print; inblk=0; next}
    inblk==0 {print}
  ' "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
  rm -f "$tmpc"
}

# Compute per-milestone percentages and render blocks
pmvp=$(percent "$done_weight_MVP" "$total_weight_MVP")
palpha=$(percent "$done_weight_Alpha" "$total_weight_Alpha")
pbeta=$(percent "$done_weight_Beta" "$total_weight_Beta")
pv1=$(percent "$done_weight_v1" "$total_weight_v1")

# Overall weighted blend
omvp=$pmvp ; oalpha=$palpha ; obeta=$pbeta ; ov1=$pv1
overall=$(( (40*omvp + 30*oalpha + 20*obeta + 10*ov1) / 100 ))

# Update docs/tasks/README.md
content_mvp=$(render_pb "MVP" "$pmvp" "$done_count_MVP" "$total_count_MVP" )
content_alpha=$(render_pb "Alpha" "$palpha" "$done_count_Alpha" "$total_count_Alpha" )
content_beta=$(render_pb "Beta" "$pbeta" "$done_count_Beta" "$total_count_Beta" )
content_v1=$(render_pb "v1.0.0" "$pv1" "$done_count_v1" "$total_count_v1" )
bos=$(bar "$overall")
content_overall=$(printf '#### %s\n```text\n%s %s%% (weighted)\n|••••|••••|••••|••••|••••|••••|••••|••••|••••|••••|\n0   10   20   30   40   50   60   70   80   90  100%%\n```\n' "Overall" "$bos" "$overall")

replace_block "$README_TASKS" "MVP" "$content_mvp"
replace_block "$README_TASKS" "Alpha" "$content_alpha"
replace_block "$README_TASKS" "Beta" "$content_beta"
replace_block "$README_TASKS" "v1.0.0" "$content_v1"
replace_block "$README_TASKS" "Overall" "$content_overall"

# Update root README Overall block
replace_block "$README_ROOT" "Overall" "$content_overall"

echo "Updated progress bars: MVP=${pmvp}% Alpha=${palpha}% Beta=${pbeta}% v1=${pv1}% Overall=${overall}%"
