# ⚠️ CRITICAL WARNING

**NEVER RUN SHIPLOG TESTS LOCALLY OR DIRECTLY**

> [!WARNING]
> Shiplog tests manipulate Git repositories and can cause irreversible damage to your working repository if run outside the controlled Docker environment.

How to run tests safely (Dockerized):

- Use `make test` from the repo root. This spins up Docker and runs the full Bats suite in an isolated container.
- Do not invoke Bats or individual test files directly on the host.
- CI runs the same flow via the bash matrix. If you need distro-specific runs locally, use `ci-matrix/run-all.sh`.
 - Tests default to `SHIPLOG_USE_LOCAL_SANDBOX=1` (no network clones); set to `0` only if you explicitly need to hit the remote sandbox repo.
## Test Timeouts

- The suite no longer enforces a timeout by default. Runs will continue until completion unless you opt in.
- To enable a guard in any environment, set `TEST_TIMEOUT_SECS` to a positive integer (e.g., `TEST_TIMEOUT_SECS=180 make test`).
- You can still wrap the outer `make test` call with `timeout`/`gtimeout` if you suspect a hang.
- In CI, rely on the job/step timeout or export `TEST_TIMEOUT_SECS` for an additional safety net.
- If a timeout occurs, capture and attach logs from `ci-logs/*` or the container output for debugging.

Note: The suite still defaults to the local sandbox (`SHIPLOG_USE_LOCAL_SANDBOX=1`) to avoid network clones.
# Git Workflow Guidelines

## Quick Reminders

- Never push directly to main; create a branch and open a PR instead.
- Never amend commits or force-push to shared branches without explicit user approval; amending local commits is encouraged.
- If a task appears to require a force push, stop and ask the user before proceeding.

## Branch Management

- Never push directly to `main`. Create a feature branch from `main` and open a pull request for review.
- Use descriptive branch names with prefixes (e.g., `feature/`, `bugfix/`, `hotfix/`)
- Delete feature branches after successful merge to keep the repository clean
- Regularly sync feature branches with `main` to avoid merge conflicts
- Keep feature branches focused and short-lived when possible

## Commit History

- Never amend commits or force-push to shared branches without explicit user approval.
- For local branches, prefer `git commit --amend` for fixing recent commits.
- For shared branches, add new commits and use merge commits to preserve history.
- Write clear, descriptive commit messages following conventional commit format
- Make atomic commits that represent single logical changes
- Avoid "WIP" or "fix typo" commits in the final PR history

## Force Push Policy

- If a task requires force-pushing to a shared branch, stop and request explicit user approval before proceeding.
- Always use `git push --force-with-lease` instead of `git push --force` to prevent overwriting others' work.
  (This keeps teammates' commits safe: `--force-with-lease` aborts if the remote moved, so you never clobber unseen changes.)

## Progress Bar Maintenance

- Tasks have moved to `docs/tasks/` (backlog/active/complete) as JSON files.
- Use the automation to refresh progress bars:
  - `make progress` (runs `scripts/update-task-progress.sh`)
  - Updates bars in `docs/tasks/README.md` and the Overall bar block in the root `README.md`.

---
## Lessons Learned

- Tests that exercise Bosun must run inside the container; native runs may pass even when tab parsing fails under Docker. Always validate UI paths in the same environment CI uses.
- Structured output (Bosun tables) should be constructed column-by-column to avoid shell quoting surprises; use `$'\t'` concatenation rather than embedding literal tabs in a single string.
- Plugin scripts run with full privileges—enforce canonical path checks and clear execution contracts so extensions can’t escape the sandbox. Document the security expectations alongside hooks.

---
## Testing

- Always run the full test suite before pushing to shared branches
- Use project-defined test commands (e.g., `make test`) rather than running tests directly
- Ensure tests pass in the same environment they'll run in CI/CD

---
## Project-Specific Notes

- Shiplog tests must run inside Docker via `make test`; never run them directly on the host
- Keep runtime/test dependencies to stock POSIX tools plus `jq`; avoid introducing other external binaries.

---
## Backlog

Tasks are now tracked under docs/tasks/. See:

- [[docs/tasks/backlog/]]
- [[docs/tasks/active/]]
- [[docs/tasks/complete/]]
- [[docs/tasks/README.md]] (progress bars & formula)

---
## Daily Notes

### Daily Note – 2025-09-25

- Stabilized policy JSON output and CLI JSON paths:
  - `git shiplog policy show --json` now robustly returns valid JSON; trailing `--json` flag supported.
  - Added `git shiplog show --json` and `--json-compact` for single-entry JSON output.
- Test reliability and timeouts:
  - Enforced in-container timeout for Bats via the Docker test entrypoint; `TEST_TIMEOUT_SECS` env supported.
  - Default tests use `SHIPLOG_USE_LOCAL_SANDBOX=1` to avoid network clones; added `BATS_FLAGS` support for stderr on failure.
- Fixed Alpine/Arch CI:
  - Removed hard Perl dependency in Bosun (`strip_ansi` fallback) and installed `ssh-keygen` in matrix images.
  - Normalized policy writes (jq -S) and treated semantically-equal JSON as no-op to stop backup churn across distros.
- Installer safety:
  - `scripts/install-shiplog.sh` now fetches tool refs inside the installer repo (`$SHIPLOG_HOME`) and never mutates the caller repo; force-refreshes tool refs.
- GitHub hosting/docs/tooling:
  - Added docs/hosting/github.md and docs/runbooks/github-protection.md; explained custom refs vs branch namespace and protections.
  - Shipped a migration helper: `scripts/shiplog-migrate-ref-root.sh`; CLI wrapper `git shiplog refs migrate` plus `refs root show|set`.
  - Added importable Ruleset JSON and Actions workflows under `docs/examples/github/` for branch namespace and custom-refs auditing.
- README refresh:
  - Added “GitHub Hosting” links, Environment Reference, Quick copy/paste commands, JSON-only `show` examples.

### Daily Log – 2025-09-26

- MVP docs + release
  - Full features docs sweep; added docs/features/command-reference.md.
  - test/README.md aligned with snapshot runner, timeouts, local sandbox.
  - Tasks MoC generator (scripts/update-task-moc.sh) and populated docs/tasks/README.md; kept progress bars updated (scripts/update-task-progress.sh UTF‑8 fix).
  - Opened and merged MVP PR (feat/github → main); tagged and pushed v0.1.0-mvp.
- CI/CD signing
  - Fixed shiplog-sign workflow to bind to the selected environment and read CI_SSH_PUBLIC_KEY from environment variables (vars.*) instead of env.*.
- CLI improvements
  - git shiplog write: new flags (--service/--reason/--status/--ticket/--region/--cluster/--namespace/--image/--tag/--run-url, --env), non-Bosun prompt fallbacks.
  - Signing robustness: fixed unbound array expansion in sign_commit under set -u.
- README
  - Linked Command Reference; kept Overall bar mirrored from docs/tasks.

### Daily Log – 2025-09-24

- Fixed Bosun non-TTY input hang: scripts/bosun now properly handles empty stdin in non-interactive environments by implementing timeout-based input detection (resolves issue where CI pipelines would hang indefinitely).
- Completed setup wizard (Open/Balanced/Strict) with per-env strictness, non-interactive flags, backups/diffs, and --dry-run.
- Implemented per-environment `require_signed` in CLI and hook; policy show includes per-env mapping (plain + JSON).
- Hardened trust bootstrap (env-driven, removed stray prompt loop, repo-root paths, wizard uses --no-push).
- Synced policy ref layout to `.shiplog/policy.json` in the policy ref tree.
- Test harness: local sandbox option, remove upstream origin, non-interactive SSH signing; added wizard/per-env tests.
- Aligned CI artifact paths; added cross-distro bash matrix workflow.
- Full Dockerized test suite passes: all 40 Bats test cases complete successfully across Docker environments.
 - Archived: Complete policy and sync tooling hardening (see docs/archives/AGENTS/completed-2025-09-25.md)
 - Archived: Refactor installers and uninstallers for path safety (see docs/archives/AGENTS/completed-2025-09-25.md)

- Archived: Finish sandboxed test migration and isolation (see docs/archives/AGENTS/completed-2025-09-25.md)

> Note: All task checklists have been migrated to `docs/tasks/`.

For the current backlog, active work, and completed items, see:

- docs/tasks/backlog/
- docs/tasks/active/
- docs/tasks/complete/

Progress bars are now maintained in `docs/tasks/README.md` (and mirrored into the root README) by `scripts/update-task-progress.sh`.

## Memoir – Release v0.2.0 (The Cut of Your Jib)

### What We Attempted
Delivered Shiplog v0.2.0 “The Cut of Your Jib”: implemented `git shiplog run`, `git shiplog append`, `git shiplog trust show`, hardened tests, and polished release artifacts. Tag v0.2.0 is live.

### Key Decisions & Why
- Documented trailer schema (`docs/reference/json-schema.md`) to remove guesswork for consumers.
- Gave `test/17_append_and_trust.bats` a unique journal per run plus cleanup to stop cross-run failures.
- Used `release/v0.2.0` as staging branch for the PR/tag to keep history clean.

### What Worked
- `cmd_run` in `lib/commands.sh` captures structured run metadata and attaches logs as intended.
- `cmd_append` handles `--json`/stdin payloads and namespace defaults correctly.
- `cmd_trust show` surfaces trust roster/signers in both table and `--json` forms.
- Docs (README, `docs/releases/v0.2.0.md`, CHANGELOG) reference real paths/examples and pass review.

### What Failed or Was Painful
- CI flakiness from lingering journal refs in `test/17_append_and_trust.bats`; required unique env + cleanup trap.
- Initial release note file misnamed (`v020.md`) and needed cleanup.
- Too-strict empty-state assertions in the stdin append test caused rerun failures.

### Lessons & Patterns
- Tests manipulating Git refs must self-clean (`git update-ref -d`) and avoid assuming empty state.
- Generate unique identifiers per test (`$RANDOM`, `BATS_TEST_NUMBER`) to prevent collisions.
- Explicit documentation (schema, release notes, README) smooths review.

### Unresolved Threads
- UNKNOWN whether runbook task `SLT.BETA.015` will ship before next release.

### Next Moves
- NONE (release tagged and published).
\n## NEXT SESSION
yeah, cross-link it. if there's not a section in the README about githosts and what we recommend, add a brief section. In fact... please feel free to completely rewrite the README. Before doing so, however, please read through the AGENTS.md, the existing README, and all the docs/ - we should be clear about which features are currently live and which are on the roadmap, which should also be described briefly. Try to write the README to be clear, memorable, effective, and worthy of 10k stars on GitHub. HOO RAH.\n
{"date":"2025-10-04","time":"05:45","summary":"Landed trust verification (sig_mode), UX polish, auto-push/publish controls, fixed CI regressions, added linters and opened hosting matrix doc PR.","topics":[{"topic":"Trust verification + sig_mode","what":"Added chain/attestation modes and shared verifier; gated trust-commit signature by env","why":"Enable quorum enforcement and restore tests expecting unsigned trust commit","context":"Hook started requiring signed trust commits which broke tests 27/28/34/44","issue":"Unsigned trust commits rejected by default and unbound var in hook","resolution":"Made trust-commit signing opt-in via SHIPLOG_REQUIRE_SIGNED_TRUST; fixed nounset and case","future_work":"Add tests for signed-trust gate on and refine messages","time_percent":25},{"topic":"Run UX + output","what":"Minimal confirmation (🪵) and hidden optional fields in headers/ls","why":"Reduce noise and improve readability for small teams","context":"Original preview was verbose and '?' placeholders looked broken","issue":"Too chatty run output; confusing placeholders","resolution":"Stream output; emoji-only confirmation; ls pulls JSON and uses '-'","future_work":"Optional compact ls mode that hides empty columns","time_percent":15},{"topic":"Auto-push + publish","what":"Respected git config shiplog.autoPush and added git shiplog publish","why":"Avoid triggering pre-push hooks mid-deploy; explicit finalize step","context":"Deploys disrupted by hooks; desire to push at end","issue":"Auto-push always on unless env flag","resolution":"Precedence flags>config>env; new publish command","future_work":"Consider flipping default in a future minor with deprecation note","time_percent":10},{"topic":"CI/CD fixes","what":"Repaired failing bats (trust push, run --dry-run) and task-progress whitespace diff","why":"Matrix CI was red on Alpine and task-progress job","context":"Hook enforced trust signing; generator vs file whitespace mismatch","issue":"Unbound var, signature gate, and blank line under 'Overall'","resolution":"Gate trust signing; restore dry-run preview; update generator to stable format","future_work":"Lock generator format and lint only non-generated sections","time_percent":25},{"topic":"Linters & workflows","what":"Added shellcheck, markdownlint-cli2, yamllint workflow (initially non-blocking)","why":"Keep quality high without blocking existing PRs","context":"CodeRabbit flagged markdown and shell issues","issue":"Early failures would block iterative work","resolution":"continue-on-error/|| true initially; plan to tighten later","future_work":"Flip to blocking once baseline is clean","time_percent":10},{"topic":"Hosting matrix docs & PR mgmt","what":"Opened docs/hosting/matrix.md and cross-link plan","why":"Provide prescriptive SaaS vs self-hosted guidance","context":"User asked for guidance and cross-linking","issue":"No single page summarizing host capabilities","resolution":"Created matrix page PR; will cross-link in README and github.md","future_work":"Add README section and cross-links next session","time_percent":15}],"key_decisions":["Make trust-commit signature optional by default; gate with SHIPLOG_REQUIRE_SIGNED_TRUST","Keep run confirmation minimal (emoji), configurable via SHIPLOG_CONFIRM_TEXT","Respect repo config shiplog.autoPush and add explicit publish command","Normalize task-progress generator format to avoid CI whitespace diffs"],"action_items":[{"task":"Cross-link hosting matrix from docs/hosting/github.md and add a brief Git hosts section in README","owner":"assistant"},{"task":"Rewrite README after reviewing AGENTS.md, current README, and all docs (clarify live features vs roadmap)","owner":"assistant"},{"task":"Add test that enforces SHIPLOG_REQUIRE_SIGNED_TRUST=1 behavior (unsigned trust push fails, signed passes)","owner":"assistant"}]}
{"date":"2025-10-04","time":"00:42","summary":"Rewrote README and cross-linked hosting docs; added Git Hosts section, trust-mode guidance, and publish/auto-push notes.","topics":[{"topic":"README rewrite","what":"Structured Quick Start, Core Concepts, live vs roadmap","why":"Clarify scope and make landing page star-worthy","context":"User asked for a clear, memorable README aligned to current features","issue":"Prior README mixed narrative with missing hosting guidance","resolution":"Reorganized sections, added links, concise examples","future_work":"Add diagrams/screenshots and a short FAQ","time_percent":45},{"topic":"Hosting cross-links","what":"Linked github guide to matrix; added README Git Hosts section","why":"SaaS vs self-host enforcement differs and confuses users","context":"docs/hosting/matrix.md existed but wasn’t cross-linked everywhere","issue":"Users may miss SaaS limitations and branch-namespace advice","resolution":"Added prominent links and short recommendations","future_work":"Add CI workflow snippets inline for each host","time_percent":25},{"topic":"Auto-push & publish","what":"Documented precedence and explicit publish command","why":"Pre-push hooks disrupt deploys; users want a finalize step","context":"New `git shiplog publish` command and `shiplog.autoPush` config","issue":"README lacked guidance on when refs actually push","resolution":"Added section with examples and precedence","future_work":"Consider flipping default in a future minor release","time_percent":15},{"topic":"Trust modes synopsis","what":"Explained chain vs attestation and quick pick","why":"Help teams choose without deep-diving docs first","context":"TRUST.md holds details; README needs summary","issue":"Choice was under-explained on the landing page","resolution":"Concise pros/cons with pointers to TRUST.md","future_work":"Add a one-page questionnaire and CLI wizard","time_percent":15}],"key_decisions":["Support both trust modes; keep choice per-repo with simple guidance","Recommend branch namespace + Required Checks on SaaS; hooks on self-hosted","Document explicit publish and autoPush precedence prominently"],"action_items":[{"task":"Commit README/docs changes on a docs branch and open PR","owner":"assistant"},{"task":"Add brief Git Hosts note to project site/docs index","owner":"assistant"}]}
{"date":"2025-10-04","time":"00:50","summary":"Updated TRUST gate docs, env reference, hosting matrix/runbook, command reference, write docs, and release notes to reflect publish/auto-push precedence and SaaS vs self-host enforcement.","topics":[{"topic":"Trust gate & env","what":"Documented SHIPLOG_REQUIRE_SIGNED_TRUST with defaults and recommendations","why":"Prevent confusion about signature requirements and broken tests","context":"Gate defaults off; recommended on in production; SaaS requires checks","issue":"Docs previously implied always-on signature requirement","resolution":"Added explicit gate section to TRUST.md and env reference","future_work":"Add tests for gate=1 path and include examples in runbook","time_percent":35},{"topic":"Hosting guidance","what":"Linked matrix to ruleset/workflow examples and added resources","why":"Make SaaS protections prescriptive and discoverable","context":"Examples existed but weren’t linked from guidance pages","issue":"Users might miss JSON imports and CI verify flows","resolution":"Added links and clearer recommendations","future_work":"Add snippets for GitLab/Bitbucket equivalents","time_percent":25},{"topic":"Auto-push & publish","what":"Clarified precedence and added docs to command/env references","why":"Avoid pre-push hook disruption during deploys","context":"New publish command and repo config shiplog.autoPush","issue":"Precedence and examples were scattered","resolution":"Centralized in README, command-reference, write.md, env.md","future_work":"Consider default flip and deprecation notice in a future minor","time_percent":20},{"topic":"Feature docs polish","what":"ls missing-values policy; run confirmation; modes per-env strictness","why":"Align docs to current behavior and per-env support","context":"Old FAQ said per-env was future; now supported","issue":"Drift between docs and behavior","resolution":"Updated modes.md with per-env example and wizard flag","future_work":"Add a small diagram for trust modes","time_percent":20}],"key_decisions":["Recommend enabling trust-commit signature gate in production","Encourage branch namespace + Required Checks on SaaS hosts","Document precedence: flags > git config > env"],"action_items":[{"task":"Commit and open PR for docs updates","owner":"assistant"},{"task":"Add GitLab/Bitbucket CI templates mirroring GitHub workflows","owner":"assistant"}]}
{"date":"2025-10-04","time":"01:10","summary":"Added `git shiplog config` wizard (interactive/dry-run/apply) and docs; updated references to prefer config over setup for host-aware guidance.","topics":[{"topic":"Config wizard","what":"New `git shiplog config --interactive` with apply/dry-run and answers-file","why":"Provide guided, host-aware onboarding and reduce misconfiguration","context":"User requested questionnaire but under `config` instead of `setup`","issue":"No interactive questionnaire existed","resolution":"Implemented CLI, plan JSON output, local apply for policy/refRoot/autoPush","future_work":"Expand questions, emit CI/ruleset files, add Bats tests","time_percent":70},{"topic":"Docs updates","what":"Added features/config.md; linked from README, docs index, command reference","why":"Make the wizard discoverable and accurately described","context":"Existing docs referenced future questionnaire under setup","issue":"Docs drift and naming","resolution":"Updated references and backlog task to new command name","future_work":"Tutorial path + GIF of flow","time_percent":30}],"key_decisions":["Name the questionnaire `git shiplog config` with --interactive/--wizard","Default branch namespace on SaaS; custom refs on self-hosted","Apply mode writes policy/config locally but does not push"],"action_items":[{"task":"Add Bats tests for config wizard (dry-run + apply); cover SaaS vs self-hosted defaults","owner":"assistant"},{"task":"Emit workflow/ruleset files when requested (e.g., --emit-ci) and link in plan","owner":"assistant"}]}
