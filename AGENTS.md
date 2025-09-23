# ⚠️ CRITICAL WARNING

**NEVER RUN SHIPLOG TESTS LOCALLY OR DIRECTLY**

Shiplog tests manipulate Git repositories and can cause irreversible damage to your working repository if run outside the controlled Docker environment. Always use the designated test commands.
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

## Worklog

```
█████████████████▓░░ 86%
44/51 complete (7 remaining)
```

### Daily Log – 2025-09-22

- Rebased branch onto latest `main`; verified new commits (`3390bda`, `9e115b2`) keep trust/policy flow stable inside Docker.
- Hardened developer tooling: guarded `test.sh` against host execution, standardized Docker compose/Makefile resource names, and fixed jq trailer parsing so Bats passes.
- Converted `.devcontainer/scripts/verified-download.sh` to pure Bash to drop the extra interpreter dependency.
- Ran `make test` in Docker (pass) and noted `ci-matrix/run-all.sh` still needs an arm64-friendly Arch base image.
- Updated this worklog (86% complete) and marked “Enforce trust workflow in hooks and tests” plus “Finish sandboxed test migration and isolation” as done.

- [ ] Add GitHub Actions bash matrix workflow
```yaml
priority: P1
impact: ensures ./test.sh runs across Debian/Ubuntu/Fedora/Alpine/Arch on every push/PR
steps:
  - add .github/workflows/bash-matrix.yml using provided template (Buildx cache, logs artifact)
  - verify ci-matrix dockerfiles + repo test.sh meet workflow expectations
  - adjust volume mount permissions if test suite needs write access
blocked_by: []
notes:
  - workflow uploads per-distro logs; requires Docker on GitHub-hosted runner
```

- [x] Add cross-distro Docker matrix for CI
```yaml
priority: P1
impact: verifies shiplog works across mainstream distros and ensures modern Git defaults
steps:
  - add ci-matrix Dockerfile for Debian, Ubuntu, Fedora, Alpine, Arch with consistent run-tests entrypoint
  - provide docker-compose.yml and run-all.sh wrapper to build/run each image mounting repo at /work
  - add repo-root test.sh that run-tests can invoke (wrapper around bats -r test or chosen suite)
blocked_by: []
notes:
  - images must install bash/git/coreutils and set init.defaultBranch main to avoid legacy warnings
```

- [x] Migrate CLI interactions to Bosun
```yaml
priority: P0
impact: removes legacy dependency and unifies interactive UX
steps:
  - wire git-shiplog prompts (input/confirm/choose/table) to scripts/bosun
  - replace legacy references in installers, README, Docker image, and environment docs with Bosun guidance
  - delete old shims and extend tests to cover Bosun help output
blocked_by: []
notes:
  - cleanup includes updating release packaging and CI images
```

- [ ] Harden scripts/bosun runtime safety
```yaml
priority: P1
impact: prevents malformed docs paths and ANSI/TSV parsing bugs
steps:
  - validate BOSUN_DOC_ROOT and fail fast on invalid/unsafe paths
  - replace ANSI stripping/parsing with single robust implementation
  - implement safe CSV/TSV parsing without fragile IFS/globbing
blocked_by: []
notes:
  - ensure shellcheck passes after refactor
```

- [x] Enforce trust workflow in hooks and tests
```yaml
priority: P0
impact: guarantees signed trust/policy refs and reliable journal enforcement
steps:
  - refactor contrib/hooks/pre-receive.shiplog to fail-fast on missing trust blobs and validate seq/trust_oid
  - build a local non-SSH hook harness and re-enable skipped pre-receive tests
  - ensure test harness mirrors new trust bootstrap and stale-trust rejection cases
blocked_by: []
notes:
  - harness now provisions sandbox remotes with trust/policy refs; stale-trust cases validated in test/11
```

- [ ] Document signing workflow and add failure-path coverage
```yaml
priority: P1
impact: clarifies operations and prevents silent misconfigurations
steps:
  - extend README/docs/features with end-to-end signing workflow (install, trust sync, journal push)
  - add tests for missing/invalid allowed signers and loopback signing paths
  - capture known failure messages for audit friendliness
blocked_by: []
notes:
  - coordinate with hook enforcement changes to keep messaging consistent
```

- [ ] Complete policy and sync tooling hardening
```yaml
priority: P1
impact: stabilizes policy resolution and schema validation
steps:
  - finish lib/policy.sh refactor (default signing behaviour, author aggregation)
  - update scripts/shiplog-sync-policy.sh to detect jq --schema cleanly
  - ensure resolve_signers_path and policy parsing align with new trust model
blocked_by: []
notes:
  - cross-validate against docs/TRUST.md examples
```

- [ ] Refactor installers and uninstallers for path safety
```yaml
priority: P1
impact: avoids destructive rm/git operations on unsafe paths
steps:
  - replace install script path resolution with pure-shell realpath/readlink logic
  - remove embedded interpreters from uninstall script or move them into a standalone helper with validation
  - add regression tests covering FORCE/DATA dir edge cases
blocked_by: []
notes:
  - align logging with README security guidance
```

- [x] Finish sandboxed test migration and isolation
```yaml
priority: P0
impact: prevents mutations to real remotes and exercises new trust flow
steps:
  - convert remaining tests (02,09,11,13,helpers) to use shiplog-testing-sandbox clone helpers
  - add jq-aware trailer helpers and ensure failures surface clearly
  - guarantee tests create throw-away remotes/repos and restore git config state
blocked_by: []
notes:
  - all bats suites now bootstrap isolated clones; journal JSON assertions use git cat-file helpers
```

- [ ] Align shellcheck coverage and suppressions
```yaml
priority: P2
impact: keeps scripts maintainable and CI-friendly
steps:
  - run shellcheck across bin/ and scripts/ ensuring warnings addressed or documented
  - update Makefile/CI to run lint and capture expected suppressions
  - document lint requirements in README or CONTRIBUTING
blocked_by: []
notes:
  - depends on Bosun/installer refactors to settle
```

- [x] Extract `.devcontainer` postCreateCommand into `.devcontainer/post-create.sh` and call it from the JSON.
- [x] Harden `scripts/install-shiplog.sh`: safe `run()`, validate install dir, detect remote default branch, sync `_shiplog/*` fetch.
- [x] Harden `scripts/uninstall-shiplog.sh`: warn on unpushed refs (`--force` override), safe profile cleanup with portable guard.
- [x] Refactor `lib/common.sh` JSON escaping/logging helpers.
- [x] Replace `maybe_sync_shiplog_ref` with robust fetch/push handling and clear errors.
- [x] Remove legacy `is_boring` fallback in `lib/git.sh` and standardise env vars.
- [x] Split policy author extraction logic and improve `docs/features/init/verify` plus new schema docs.
- [x] Improve `scripts/bosun` ANSI stripping, JSON escaping, table parsing.
- [x] Update `README.md` installer instructions (no `curl|bash`), flag consistency, remove progress bar, adjust feature table evidence.
- [x] Document uninstaller and auto-push behaviour in README & env vars.
- [x] Create `.devcontainer/post-create.sh`, make executable.
- [x] Update CONTRIBUTING docs (`contrib/README.md`) paths for clarity.
- [x] Add warning about remote refs being preserved.
- [x] Update test suite:
  - [x] Simplify count helpers in `test/01_init_and_empty_ls.bats`.
  - [x] Expand `test/10_boring_mode.bats` assertions for all SHIPLOG_* vars.
  - [x] Refactor `make_entry` in `test/11_pre_receive_hook.bats` to use locals/clear args.
  - [x] Remove subshells in `test/13_uninstall.bats` git checks.
  - [x] Clarify `test/README.md` (image name, sandbox script) and rename MoC header.
- [x] Adjust README feature table (evidence links or drop Finished column) and policy example (env overrides, schema, semantic version).
- [x] Update scripts to support canonical `--yes`/`SHIPLOG_ASSUME_YES` naming and remove redundant `--boring` pre-scan.
- [x] Add JSON schema (`examples/policy.schema.json`) and link in docs/CI.
- [x] Investigate and fix the failing Dockerized test suite after the CLI/runtime changes.
- [x] Restore the signing test when reliable GPG automation exists in CI.
- [x] Update Docker test harness to work on a copied repo snapshot (no bind mount) and ensure tests create isolated git remotes.
- [x] docs/bosun/choose.md — add an interactive example showing menu prompt, user input, and output.
- [x] docs/bosun/confirm.md — normalize examples (consistent comments, JSON formatting, decline scenario + exit codes).
- [x] docs/bosun/input.md — add edge-case examples (empty stdin, non-tty behaviour, placeholder+default) with outputs/exit codes.
- [x] docs/bosun/overview.md — expand each command description with purpose, flags, defaults, and a concise example.
- [x] docs/features/init.md — clarify the `core.logAllRefUpdates` explanation with concrete behaviour and implications.
- [x] docs/features/ls.md — document ENV parameter and add multiple usage examples.
- [x] docs/features/policy.md — replace buzzwords with explicit precedence rules, add minimal + full policy examples, schema reference, override mapping.
- [x] docs/features/write.md — enumerate all supported `SHIPLOG_*` env vars (purpose, type, defaults, examples).
- [x] docs/policy.md — correct validation guidance, provide full authors JSON example, note schema/override usage.
- [x] examples/policy.json — resolve signers file path deterministically (absolute/homedir) and adjust docs.
- [x] examples/policy.schema.json — tighten Git ref regex validation for notes/prefix fields.
- [x] lib/commands.sh — remove ensure_config_value helper and refactor maybe_sync_shiplog_ref via new helper functions; simplify artifact construction.
- [x] lib/common.sh — improve JSON escaping fallback (or require jq), validate env var names/blacklist, refactor prompt helpers, add logging helper.
- [x] lib/git.sh — source common.sh explicitly, enable strict mode, standardize Bosun fallback messaging.
- [x] .devcontainer/scripts/verified-download.sh — capture resolver output, fail on errors.
- [x] contrib/README.md — format install script as fenced bash block without diff artefacts.

## Testing

- Always run the full test suite before pushing to shared branches
- Use project-defined test commands (e.g., `make test`) rather than running tests directly
- Ensure tests pass in the same environment they'll run in CI/CD

### Project-Specific Notes

- Shiplog tests must run inside Docker via `make test`; never run them directly on the host
- Keep runtime/test dependencies to stock POSIX tools plus `jq`; avoid introducing other external binaries.
