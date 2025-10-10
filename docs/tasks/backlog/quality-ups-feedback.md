James, buckle up. Here’s the Captain’s Measure™—a no‑nonsense teardown of Shiplog as it stands today, plus the Quality‑Ups™ and ENHANCED DX™ that will turn it from great to LEDGERED‑ARY.

⸻

Executive summary (tell‑it‑like‑it‑is)

What slaps:
	•	Logs of Provenance™ is real—not marketing. git shiplog run captures stdout+stderr, timestamps, exit code, duration, and links it all to the journal entry; the log is stored as a Git note. That’s an immutable deploy transcript.  ￼  ￼
	•	Human + JSON UX, everywhere. show surfaces the human + trailer + notes; export-json emits NDJSON for machines.  ￼
	•	Policy-as-code with real precedence rules + multi-sig trust. This is opinionated in the right places.   ￼
	•	Init is idempotent and safe (refspecs + reflogs) and environment resolution is consistent.  ￼  ￼

Where it squeaks:
	•	JSON/flag semantics are 95% consistent—tighten the last 5% (JSON mode flags and output shapes across commands).  ￼
	•	We can bind Shiplog entries ↔ Git tags to make releases and deploys a single navigable graph.
	•	Missing a few DX power moves (redaction, tail/grep of notes, fast filters, replay capsules).

Overall: You built a Git‑native black box recorder for deployments. Now we make it an operational operating system.

⸻

Dealership 18‑Point Inspection™ (graded)
	1.	CLI topology & global flags — A‑
Cohesive global flags (--env, --boring, --yes, --dry-run, --no-push). Strong baseline.  ￼
	2.	Environment resolution — A
Stable resolution order (arg → --env → SHIPLOG_ENV → default prod). Applies across commands.  ￼
	3.	Dry‑run semantics — A
run --dry-run previews without side effects; setup has a clean dry‑run too. Nice.  ￼
	4.	Journal/notes layout — A
Journals under refs/_shiplog/journal/<env>; notes under refs/_shiplog/notes/logs. Configurable via policy.   ￼
	5.	Log capture + linking (run) — A
Captures stdout/stderr, duration, exit code; attaches as note; returns wrapped exit code. Chef’s kiss.  ￼
	6.	Human/JSON output — A‑
show has --json, --json-compact, --jsonl; export-json streams NDJSON with commit. Great—normalize option names everywhere.  ￼
	7.	Signing policy + trust — A‑
Clear unsigned/signed modes; chain vs attestation; server enforcement knobs. Strengthen docs linking from CLI help.  ￼  ￼
	8.	Author allowlist & verification — A
Verify reports OK/BadSig/Unauthorized; policy precedence is spelled out.
	9.	Push behavior & precedence — B+
Auto‑push defaults and precedence (flag > git config > env) are documented; publish exists for manual pushes. Consider a per‑command --push=auto|always|never.  ￼  ￼
	10.	Init idempotence — A
Refspecs + core.logAllRefUpdates + no-op if configured. Safe.  ￼
	11.	Trailer validation — A
validate-trailer with structural checks and jq requirement. Solid.
	12.	Bosun UI fallback — A
Pretty when present, boring when not; same behavior across commands.  ￼  ￼  ￼
	13.	Exit codes — A
run mirrors wrapped exit; validate/verify exit non‑zero on failure. Good for CI.  ￼
	14.	Attachments — A
Notes API is clean; SHIPLOG_LOG path → note add → show renders.  ￼
	15.	Non‑interactive/scriptability — A‑
write + envs + append JSON merge via SHIPLOG_EXTRA_JSON. Consider documenting exact merge precedence more.  ￼  ￼
	16.	Policy resolution order — A
Clear, deterministic precedence and merge rules; example outputs. Great.
	17.	Ref root & migration — A‑
refs root show|set, refs migrate for branch‑namespace hosting. Add a “status” view.  ￼
	18.	Setup & config wizards — B+
config (interactive) vs setup (flag‑driven). Consider one “golden path” doc page.  ￼

⸻

Quality‑Ups™ (low effort, high impact)
	1.	Normalize JSON flags across commands
	•	What: Ensure --json, --json-compact, --jsonl exist (or consciously don’t) on every command that returns records (e.g., extend to verify, ls).
	•	Why: Predictability → muscle memory.
	•	Refs: Current split across show/export-json.  ￼
	2.	--push=auto|always|never (tri‑state) everywhere
	•	What: Replace --no-push/--push booleans with a tri‑state flag.
	•	Why: Makes intent explicit; less precedence confusion.
	•	Refs: Present precedence doc could stay as fallback.  ￼
	3.	shiplog show --tail & --grep for notes
	•	What: Tail last N lines and grep notes without piping.
	•	Why: 90% of incident forensics is “gimme the last 200 lines matching X”.
	•	Refs: Notes are first‑class; give first‑class filters.  ￼
	4.	Secret redaction on run (--redact key=VAL / --redact-env VAR[,VAR...])
	•	What: Mask values in captured logs; default patterns (tokens, passwords).
	•	Why: Make Logs of Provenance™ safe to share by default.
	5.	run prints prior context
	•	What: After run, print quick link to previous entry for same service + env with status/duration deltas.
	•	Why: Instant compare accelerates root cause.
	•	Refs: ls already extracts status/service/env.  ￼
	6.	shiplog policy show everywhere from help
	•	What: Help footers should hint “policy in effect: run git shiplog policy show”.
	•	Why: Reduce “why did this fail?” roundtrips.
	•	Refs: Policy doc is strong—surfacing it in CLI helps.
	7.	Bosun‑less parity test
	•	What: Add a CI test that runs every command with SHIPLOG_BORING=1.
	•	Why: Ensures the pretty path and boring path don’t drift.
	•	Refs: Multiple commands mention Bosun fallback.  ￼  ￼
	8.	shiplog verify --json
	•	What: Emit machine‑readable verdicts per entry.
	•	Why: Easier dashboards and alerts; parity with show.
	•	Refs: verify summary is textual today.
	9.	validate-trailer --json
	•	What: Print structured errors (field, expected, got).
	•	Why: Tooling hooks; IDE integration.
	•	Refs: Currently prints human error lines.
	10.	Guided “golden path” doc

	•	What: One page: init → config → run → show → verify → export-json.
	•	Why: Shorten TTV (time‑to‑value).
	•	Refs: Pieces exist, just stitch.  ￼  ￼  ￼  ￼

	11.	shiplog doctor

	•	What: Checks required tools (git, jq, perl for Bosun), signing config, policy refs present.
	•	Why: One‑shot “why is Shiplog sad?”
	•	Refs: Several commands require these implicitly.  ￼

	12.	Zero‑footgun hooks

	•	What: Ensure internal Git ops use --no-verify where hooks could recurse; or honor an env like SHIPLOG_MODE=1 to short‑circuit local hooks.
	•	Why: Avoid the “robot punches itself” scenario during deployments.

⸻

ENHANCED DX™ (the fun stuff)

1) Tag ↔ Entry Binding (“Release Provenance”)
	•	CLI: git shiplog tag-link v1.2.3 <entry> and git shiplog show --tag v1.2.3.
	•	Mechanics:
	•	Add shiplog-id:<ENTRY-OID> trailer to the annotated tag message; or
	•	Create a lightweight link ref under refs/_shiplog/anchors/tags/v1.2.3 -> <entry> (policy already names an anchors_ref_prefix).
	•	Payoff: “Show me the deploy for this release” becomes trivial.

2) shiplog diff <entryA> <entryB>
	•	Compare trailer blocks (env/service/status/reason/where), exit codes, durations, and log deltas (last N lines).
	•	Under the hood: two show --json blobs + minimal diff renderer.  ￼

3) Replay Capsule
	•	CLI: shiplog replay <id>
	•	Rehydrate the exact command and environment, with safety guardrails (--confirm, --dry-run-first).
	•	Uses the run block’s argv/cmd + context to reconstruct.  ￼

4) Provenance Search
	•	CLI: shiplog grep 'panic|OOMKilled' --env prod --since 7d
	•	Thin wrapper around export-json + jq + note reads.
	•	For quick wins: shiplog export-json | jq -r 'select(.status!="success")'.

5) Policy‑aware “Required Checks”
	•	Print next steps after write/run when policy is strict:
	•	“This env requires signatures/ticket. See: shiplog policy show.”

6) Redaction Profiles
	•	CLI: run --redact-env AWS_SECRET_ACCESS_KEY,AWS_ACCESS_KEY_ID --redact 'token=([A-Za-z0-9._-]+)'
	•	Applies masks before note attach; marks trailer with redacted=true.  ￼

7) shiplog open
	•	Open the journal entry/notes on your Git host (GitHub, etc.).
	•	Uses remote detection (already in config) to build URLs.  ￼

8) “Incident Pack” export
	•	CLI: shiplog bundle <id> --out incident-<id>.tgz
	•	Exports the trailer, note, trust summary, and optional artifacts → single file for audits.
	•	Uses show --json, trust show --json.  ￼  ￼

⸻

The Captain’s Log™ (Docs + README uplift)

Punchy hero block:

Shiplog turns deploys into Logs of Provenance™—cryptographically linked transcripts of what actually happened.
No dashboards. No archaeology. git shiplog run writes the deploy, its output, and its receipts into Git.
Signed. Greppable. Immutable.  ￼  ￼

Top 6 quick paths in README:
	1.	init (idempotent) → set refspecs + reflogs.  ￼
	2.	config --interactive → pick host/ref root/trust mode.  ￼
	3.	run -- … → logs captured as notes + metadata.  ￼
	4.	show → human + JSON + notes.  ￼
	5.	verify → signatures/authors status.
	6.	export-json → NDJSON to your data lake.

Sidebars:
	•	Signed mode on SaaS? Use branch namespace + Rulesets; server hooks on self-hosted. (Tie back to policy + trust docs.)   ￼

⸻

“DA BASH™” guardrails (code‑level patterns to adopt everywhere)
	•	Strict mode + reliable traps: set -Eeuo pipefail; IFS=$'\n\t'; trap 'rc=$?; …; exit "$rc"' ERR INT TERM.
	•	mktemp for logs & ensure cleanup on every exit path; the run temp file is critical. (Trailer already records log_attached—keep invariant tight.)  ￼
	•	Quote everything (no naked $var), use arrays for argv, prefer printf over echo.
	•	No recursing hooks: add GIT_PARAMS+=(--no-verify) in internal git commit/push helpers when SHIPLOG_MODE=1.
	•	Consistent exit disciplines: all commands exit non‑zero only for genuine failure (you’re already good here—keep it).  ￼
	•	Shellcheck gating: CI target that fails on new SC20xx/SC22xx class issues.
	•	Boring‑mode snapshots: add tests that prove plain output contains the same information as Bosun.

⸻

Concrete micro‑specs (ready to implement)

shiplog tag-link
	•	Usage: git shiplog tag-link v1.2.3 <entry>
	•	Effect: Annotated tag message gains shiplog-id:<OID> trailer and a link ref at refs/_shiplog/anchors/tags/v1.2.3 → <entry>. (Policy has anchors_ref_prefix already.)
	•	Read: git shiplog show --tag v1.2.3 resolves to the entry and prints it.  ￼

shiplog show --tail 200 --grep ERROR
	•	Effect: Only note lines matching filter are printed, with a header …(last 200 lines)….  ￼

shiplog verify --json
	•	Schema: { "env": "prod", "summary": {"ok":N,"badSig":N,"unauthorized":N}, "entries":[{"commit":"…","status":"ok|badSig|unauthorized","reason":"…"}] }

shiplog run --redact
	•	Trailer add: "redacted": true, "redact_rules": ["env:AWS_SECRET_ACCESS_KEY","regex:token=…"] in the run block.  ￼

⸻

Final word

You’ve already built the thing most teams wish their CI/CD vendor sold them: a signed, greppable, Git‑native timeline of reality. With the Quality‑Ups and ENHANCED DX above, Shiplog graduates from “clever tool” to operational truth layer.

LOOOOOOOOOGGGGS OF PROOOOOVENANCE™.
(Thunder. Jenkins flinches.)


---


(Thunder shakes the chassis. The pager dog howls. A single goat bleats.)

Alright James, let’s wire that drama straight into the CLI—tasteful by default, ridiculous on command.

Below is a drop‑in enhancement for git-shiplog/commands.sh that adds a --dramatic flag (or SHIPLOG_DRAMA=1) to tastefully unleash:
	•	a stormy banner: LOGS OF PROVENANCE™
	•	a terminal bell thunderclap (opt‑in)
	•	a tasteful 🐐 BLEAT! (also opt‑in)
	•	zero interference with CI / --boring
	•	zero change to exit codes or journal writes

⸻

⚙️ Add a little thunder (safe defaults)

1) Paste this helper where you keep common UI functions (e.g., common.sh)

# Visual thunder for humans; no-op in boring/non-tty.
shiplog_thunder_fx() {
  # message can be overridden; default to the Holy Phrase™
  local msg="${1:-LOGS OF PROVENANCE™}"

  # Respect boring/CI/TTY
  [[ "${SHIPLOG_BORING:-0}" = "1" ]] && return 0
  [[ -t 1 ]] || return 0

  # Colors (best effort)
  local bold="" reset="" yellow="" blue=""
  if command -v tput >/dev/null 2>&1; then
    bold="$(tput bold)"; reset="$(tput sgr0)"
    yellow="$(tput setaf 3)"; blue="$(tput setaf 4)"
  fi

  # Banner
  printf "\n%s🌩️  %s%s\n" "$bold" "$msg" "$reset"

  # Lightning (quick; no sleeps unless explicitly asked)
  printf "%s%s\n%s%s\n%s%s\n" \
    "$yellow" "        \\   ⚡" \
    "$yellow" "         \\  ⚡" \
    "$yellow" "          \\⚡  " 
  printf "%s\n" "$reset"

  # Optional goat
  if [[ "${SHIPLOG_DRAMA_GOAT:-1}" != "0" ]]; then
    printf "%s🐐  BLEAT!%s\n" "$blue" "$reset"
  fi

  # Optional thunderclap (BEL) — off by default
  if [[ "${SHIPLOG_DRAMA_CLAP:-0}" = "1" ]]; then
    printf '\a'  # first clap
    [[ "${SHIPLOG_DRAMA_DOUBLECLAP:-1}" = "1" ]] && { sleep 0.03 2>/dev/null || :; printf '\a'; }
  fi
}

Notes
	•	Off by default. Only runs when you ask for it.
	•	Auto‑no‑ops in --boring or non‑TTY.
	•	SHIPLOG_DRAMA_GOAT=0 silences the goat; SHIPLOG_DRAMA_CLAP=1 enables the thunder bell.

⸻

2) Parse a --dramatic flag in cmd_run (or your run wrapper)

Add to your run option parsing (minimalistic example; adapt to your parser style):

dramatic=0
run_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dramatic) dramatic=1; shift ;;
    --) shift; break ;;
    *) run_args+=("$1"); shift ;;
  esac
done
# ...the rest of cmd parsing continues, then the wrapped command after `--` is in "$@"

Set the env toggle for the rest of the function:

# allow env override, but flag wins
if [[ $dramatic -eq 1 ]]; then
  SHIPLOG_DRAMA=1
fi
export SHIPLOG_DRAMA="${SHIPLOG_DRAMA:-0}"


⸻

3) Call it after your normal confirmation output

Right where you currently print the 🪵 (or your confirmation line) after a run completes and the journal entry is written:

# existing minimal confirmation
if [[ -n "${SHIPLOG_CONFIRM_TEXT:-}" ]]; then
  printf "%s\n" "$SHIPLOG_CONFIRM_TEXT"
else
  printf "🪵\n"
fi

# ✨ optional drama
if [[ "${SHIPLOG_DRAMA}" = "1" ]]; then
  # Default phrase can be overridden:
  #   SHIPLOG_DRAMA_MSG="LEDGERED‑ARY INCIDENTS™"
  shiplog_thunder_fx "${SHIPLOG_DRAMA_MSG:-LOGS OF PROVENANCE™}"
fi

Guarantees
	•	No change to exit codes. You still mirror the wrapped command’s status.
	•	No change to the journal/trailer. Pure UI sugar (unless you want to record it; see below).

⸻

🧪 Usage (choose your spice level)

# One-off drama
git shiplog run --dramatic --service web --reason "canary" -- ./deploy.sh

# Env-driven drama (flag not required)
SHIPLOG_DRAMA=1 git shiplog run --service db --reason "migrate" -- ./migrate.sh

# Thunderclap bell + silent goat (for the minimalists)
SHIPLOG_DRAMA=1 SHIPLOG_DRAMA_CLAP=1 SHIPLOG_DRAMA_GOAT=0 git shiplog run -- ...

CI safe: In CI, set SHIPLOG_BORING=1 globally or rely on non‑TTY detection; the effect won’t render.

⸻

📎 Optional: record the drama in your trailer (tiny, tasteful)

If you want the trailer to admit it put on the fedora:

# before calling `write`, extend SHIPLOG_EXTRA_JSON
# (preserve existing JSON if set)
shiplog_extra="${SHIPLOG_EXTRA_JSON:-{}}"
if [[ "${SHIPLOG_DRAMA:-0}" = "1" ]]; then
  # naive merge: you likely already have a helper for this
  shiplog_extra=$(printf '%s' "$shiplog_extra" | jq '.fx = (.fx // {}) + {"thunder": true, "goat": (env.SHIPLOG_DRAMA_GOAT // "1") == "1"}' 2>/dev/null || printf '%s' "$shiplog_extra")
fi
export SHIPLOG_EXTRA_JSON="$shiplog_extra"

Now future you can search NDJSON for the… theatrics.

⸻

🧯 Guardrails
	•	Never print drama in --boring or non‑TTY. Leave CI clean.
	•	Keep sleeps off unless explicitly requested; fast and quiet by default.
	•	Do not modify wrapped command exit codes.
	•	Avoid recursive hooks: internal git ops should pass --no-verify in deploy automation (you already nailed this earlier).

⸻

🧱 README callout (tiny, sharp)

🌩️ LOGS OF PROVENANCE™ (optional drama)

Shiplog can add a thunderous banner when you’re running deploys from a TTY:

git shiplog run --dramatic --service web --reason "canary" -- ./deploy.sh

Set SHIPLOG_DRAMA=1 to opt in, SHIPLOG_BORING=1 or CI to keep it quiet.
No Top Men required. 🐐

⸻

Result: We keep Shiplog dead‑serious by default, but give humans a dramatic, memorable signal when they want it—without touching the ledger, exit codes, or policy flow.

Now say it with me, together, on three…

ONE. TWO. THREE.

LOOOOOOOOOGGGGS OF PROOOOOVENANCE™
(thunderclap, tasteful goat)


---


Alright James — no fluff, straight lines. Bosun.

Coach’s Verdict

Keep Bosun. But make it a renderer, not a feature.
It should never decide behavior, only how you see behavior.

Right now Bosun is doing the right thing conceptually — pretty boxes in a TTY, TSV/plain when not — and you already describe that fallback in the docs for ls, show, and run. Keep that contract iron‑clad and double down on it.  ￼ ￼ ￼

Also: you explicitly call out that Bosun depends on perl and that the CLI falls back to plain text if it’s missing. Good. That’s the right safety valve — keep it.  ￼

⸻

The Good (and why you should keep it)
	•	TTY polish where it matters. ls uses a table when interactive, TSV otherwise — that’s exactly how it should behave. Humans get fast scanning; machines get stable text.  ￼
	•	show renders a human box, or plain text. It also prints JSON‑only when asked. This is the right three‑tier design (human, plain, machine).  ￼
	•	run leverages Bosun for previews/streaming but still records the note and returns the real exit code. The pretty layer never changes semantics — perfect.  ￼

Bottom line: Bosun already acts as “presentation only” in your docs; the refactor below makes that structural in code so it can’t drift.

⸻

The Risks (why it squeaks)
	1.	Logic duplication risk. If Bosun prints from ad‑hoc shell variables while plain/JSON paths read from the trailer, they’ll drift over time.
	2.	Portability. perl and Unicode/emoji in weird terminals; Windows Git‑Bash; minimal Docker images. You do fall back today — enforce it programmatically.  ￼
	3.	CI noise. Anything “interactive” is a liability in non‑TTYs; keep --boring (and auto‑boring) as the law. You already document boring/plain fallback — now enforce and test it.  ￼ ￼

⸻

Non‑Negotiables (red lines)
	•	JSON‑first. Every screen Bosun draws should come from a single JSON blob produced by the command (or a deterministic struct), not from scattered shell vars.
	•	Renderer boundary. All commands emit one of: JSON | Plain | Renderer(Bosun(JSON)). Renderer takes JSON in → prints pretty → that’s it.
	•	Zero semantic effect. Whether Bosun is present must never change exit codes, what gets written, policy checks, or what ships to notes/journals. (You’re already doing this; keep it tight.)  ￼

⸻

The Refactor (fast, surgical)

Phase 1 — Lock the contract
	1.	Introduce a renderer switch (one place).
	•	SHIPLOG_RENDERER=auto|plain|bosun (default auto).
	•	auto = if TTY and Bosun+perl available → bosun, else plain.
	•	--boring hard‑forces plain. (You already do this; make the decision centralized.)  ￼ ￼
	2.	Make each command produce JSON first.
	•	ls: gather rows → emit JSON array (or NDJSON) → render_ls chooses pretty table vs TSV.  ￼
	•	show: fetch entry → --json returns JSON, else pass JSON to render_show. Notes are part of the “model”.  ￼
	•	run: previews and final confirmation come from the same JSON payload (run block + metadata). The log stream is strictly I/O piping; the summary is rendered from JSON.  ￼
	3.	One Bosun entrypoint per view.
	•	bosun_render_ls <json>
	•	bosun_render_show <json>
	•	bosun_render_run_preview <json>
The plain renderers are just shell printf over the same inputs.

Phase 2 — Hardening
	4.	Auto‑fallback probes.
	•	If perl missing → renderer=plain, always. (You explicitly call this out.)  ￼
	•	If NO_COLOR set or not a TTY → renderer=plain.
	•	If tput cols fails → assume width 80; no box‑drawing beyond ASCII.
	5.	Parity tests (Bats).
	•	For ls, show, run --dry-run: run once with SHIPLOG_BORING=1 and once with Bosun; assert the information set matches (field subset equality), even if formatting differs.
	6.	Doc clarity (footers).
	•	Each command’s --help footer: “Pretty TTY output uses Bosun. Set --boring or SHIPLOG_RENDERER=plain to disable.”
	•	Cross‑link: “Missing Perl? You’ll see plain output.”  ￼

⸻

Bosun Style Guide (to keep it crisp, fast, portable)
	•	ASCII by default; Unicode only when safe. Detect UTF‑8; otherwise use +---+ style boxes.
	•	Fixed palette. Use tput setaf 1..7 only; honor NO_COLOR.
	•	Stable columns. Right‑align durations, constant width for status (SUCCESS/FAILED/…); don’t reflow.
	•	Width aware. Use $COLUMNS or tput cols; ellipsis long fields instead of wrapping.
	•	No sleeps/spinners unless explicitly requested (you already have --boring; add --dramatic for memes on TTYs, default off).
	•	Zero external forks in loops. Precompute colors, avoid sed/awk per row.

⸻

“What should I actually change?” (minimal code moves)
	1.	Centralize renderer choice in one function:

choose_renderer() {
  [[ "${SHIPLOG_BORING:-0}" = "1" ]] && echo plain && return
  [[ ! -t 1 ]] && echo plain && return
  command -v perl >/dev/null 2>&1 || { echo plain; return; }
  [[ "${SHIPLOG_RENDERER:-auto}" = "bosun" ]] && echo bosun && return
  [[ "${SHIPLOG_RENDERER:-auto}" = "plain" ]] && echo plain && return
  echo bosun
}


	2.	Emit a JSON model at the end of each command’s “gather” phase; then:

case "$(choose_renderer)" in
  bosun) bosun_render_show "$json";;
  *)     plain_render_show "$json";;
esac


	3.	run --dry-run preview should be the same JSON fed into renderer; if Bosun is absent, print the plaintext preview you already describe.  ￼
	4.	Document the guarantees right in each doc:
	•	“Bosun is presentation only; behavior is identical in plain mode.”
	•	“If Perl is missing or non‑TTY, plain mode is automatic.”  ￼

⸻

Where Bosun pays for itself (the wins)
	•	ls signal density: colorized status + aligned columns = “scan 20 entries in 2 seconds”.  ￼
	•	show comprehension: human pane + JSON + log note in one shot = less context switching.  ￼
	•	run preview/readability: commands feel safer when the plan is boxed and obvious, even while logs stream to the note.  ￼

Keep those wins; just anchor them to JSON so they can’t drift.

⸻

Final answer, Coach‑style
	•	Bosun stays.
	•	Bosun moves behind a renderer boundary.
	•	Everything renders from JSON.
	•	If anything is weird (no Perl, CI, Windows), you get clean plain output automatically.  ￼ ￼ ￼

Do that, and Bosun becomes pure upside: delight when humans are present, zero surprise when they aren’t.

---

perfect. then treat Bosun like a gum-compatible renderer:
	•	same vibe: little composable UI primitives
	•	never drives behavior; just paints it
	•	auto-falls back to plain/TSV when boring/non-TTY/no perl

here’s a clean way to wire it without taking a hard dep on gum.

⸻

Bosun ≈ gum (compat layer plan)

philosophy
	•	JSON-first: every command builds a JSON model → Bosun (or gum) renders it.
	•	renderer boundary: model → render(ls|show|run_preview) only. no side-effects.
	•	auto mode: if TTY && gum installed → use gum; else native Bosun; --boring forces plain.

mode switch (single source of truth)

bosun_choose_renderer() {
  # explicit overrides
  case "${SHIPLOG_RENDERER:-auto}" in
    plain) echo plain; return;;
    bosun) echo bosun; return;;
    gum)   command -v gum >/dev/null && echo gum || echo plain; return;;
  esac
  # auto
  [[ "${SHIPLOG_BORING:-0}" = "1" ]] && { echo plain; return; }
  [[ -t 1 ]] || { echo plain; return; }
  command -v gum >/dev/null && { echo gum; return; }
  command -v perl >/dev/null || { echo plain; return; }
  echo bosun
}

primitive API (gum-ish names, native fallbacks)

# style(text, ...options)
bosun_style() {
  case "$(bosun_choose_renderer)" in
    gum)   gum style "$@";;
    bosun) _bosun_style_native "$@";;
    *)     printf "%s" "$*";;
  esac
}

# box(title, body)
bosun_box() {
  local title="$1"; shift
  local body="$*"
  case "$(bosun_choose_renderer)" in
    gum)
      # gum has nice text styling; emulate a box with style/format
      { printf "%s\n\n" "$title"; printf "%s\n" "$body"; } | gum format
      ;;
    bosun) _bosun_box_native "$title" "$body";;
    *)     printf "\n%s\n%s\n\n" "$title" "$body";;
  esac
}

# table --json '[{"col":"v",...}]' --columns col1,col2[,...]
bosun_table() {
  case "$(bosun_choose_renderer)" in
    gum)
      # if your gum has table, use it; else render via format/style
      if gum help 2>&1 | grep -q table; then gum table "$@"
      else _bosun_table_native "$@"
      fi
      ;;
    bosun) _bosun_table_native "$@";;
    *)     _bosun_table_plain "$@";;
  esac
}

tiny native fallbacks (fast & portable)

_bosun_style_native() { printf "%s" "$*"; } # keep minimal; add tput if you want
_bosun_box_native() {
  local title="$1"; shift; local body="$*"
  local cols="${COLUMNS:-80}"
  printf "\n+%*s+\n" $((cols-2)) | tr ' ' '-'
  printf "| %s\n" "$title"
  printf "+%*s+\n" $((cols-2)) | tr ' ' '-'
  printf "%s\n\n" "$body"
}
_bosun_table_plain() {
  # expected: --json J --columns c1,c2...
  local json cols
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json="$2"; shift 2;;
      --columns) cols="$2"; shift 2;;
      *) shift;;
    esac
  done
  # TSV header
  IFS=, read -r -a C <<<"$cols"
  (IFS='\t'; printf "%s\t" "${C[@]}"; printf "\n")
  jq -r --arg cols "$cols" '
    def cols: ($cols | split(","));
    .[] | [ .[cols[0]], .[cols[1]], .[cols[2]], .[cols[3]], .[cols[4]] ]
    | map(if .==null then "-" else tostring end)
    | @tsv
  ' <<<"$json"
}

use these three primitives to implement bosun_render_ls, bosun_render_show, bosun_render_run_preview from the same JSON the command already builds. gum present? you get candy. not present? still pretty enough. CI? plain TSV.

⸻

how it plugs into shiplog (examples)

ls (you already compute rows — build JSON first, then render)

rows_json="$(your_ls_to_json)"   # array of {status,service,env,author,date}
case "$(bosun_choose_renderer)" in
  plain) bosun_table --json "$rows_json" --columns status,service,env,author,date ;;
  *)     bosun_table --json "$rows_json" --columns status,service,env,author,date ;;
esac

show (one object with trailer + note)

model_json="$(your_show_to_json)" # { trailer:{...}, note:"...", meta:{...} }
if [[ "$json_flag" = 1 ]]; then printf '%s\n' "$model_json"; exit 0; fi
bosun_box "Shiplog Entry" "$(jq -r '.trailer|tojson' <<<"$model_json")"
[[ "$(jq -r '.note!=null' <<<"$model_json")" = "true" ]] &&
  bosun_box "Log (note)" "$(jq -r '.note' <<<"$model_json")"

run –dry-run (preview)

preview_json="$(build_run_preview_json)"  # {cmd,argv,env,policy_ok,...}
case "$(bosun_choose_renderer)" in
  plain) printf "Would run: %s\n" "$(jq -r '.cmd' <<<"$preview_json")" ;;
  *)     bosun_box "Run Preview" "$(jq -r '.cmd' <<<"$preview_json")" ;;
esac


⸻

guardrails (coach mode)
	•	don’t let Bosun/gum decide anything except pixels.
	•	always allow --boring / SHIPLOG_RENDERER=plain to short-circuit.
	•	never rely on gum being installed; treat it as opportunistic sugar.
	•	test parity: one Bats test per command that asserts plain vs bosun carry the same information set.
	•	keep JSON the contract. renderers are plug-replaceable.

⸻

optional: “prefer gum” switch

Need to demo with gum’s glam? Support SHIPLOG_RENDERER=gum. Folks with gum get instant sparkle; everyone else keeps cruising.

⸻

short version: yes—Bosun should feel like gum. make it a gum-compatible skin over a JSON model, with native fallbacks. then you get buttery TTY UX without tying your ledger to a UI dependency.
