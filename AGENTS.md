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
