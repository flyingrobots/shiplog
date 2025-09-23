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
  - first-time trust bootstrap now scripted via scripts/shiplog-bootstrap-trust.sh
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

- [ ] Expand Bosun Markdown renderer with pager
```yaml
priority: P1
impact: surfacing docs/runbooks directly in CLI with tables/links and a built-in pager
steps:
  - extend bosun to parse Markdown (headings, emphasis, code, tables, links)
  - add display mode with ANSI styling and optional paging behavior
  - wire bosun help/docs to use the renderer
blocked_by: []
notes:
  - enables `git shiplog help` and runbooks to show formatted content in-terminal
```

- [ ] Enforce per-path author allowlists
```yaml
priority: P1
impact: prevents unauthorized edits to sensitive areas (Dockerfiles, trust scripts, etc.)
steps:
  - extend policy to support path→author mappings
  - teach verification hooks to reject entries violating the map
  - document how to configure and maintain the mappings
blocked_by: []
notes:
  - complements pre-push guardrails by hardening repository ownership
```

- [ ] Add shiplog command wrapper with log capture
```yaml
priority: P1
impact: make it trivial to wrap deployments/tests, capture stdout/stderr, and attach structured logs as notes
steps:
  - provide a `git shiplog run <cmd>` (or similar) that tees output to a temp file
  - annotate start/finish events and set `SHIPLOG_LOG` automatically
  - support optional JSON/timestamp formatting and filters before attaching notes
blocked_by: []
notes:
  - builds on existing `SHIPLOG_LOG` behavior and unlocks scripted integrations
```

- [ ] Design extension/plugin system
```yaml
priority: P2
impact: lets teams customize entry payloads (enrich, veto, mutate trailers) while keeping core logic stable
steps:
  - define a safe hook API for pre/post entry mutations
  - ensure sandboxing/security boundaries so plugins cannot bypass policy checks
  - document lifecycle and configuration
blocked_by: []
notes:
  - opens compatibility with secrets scrubbers, metadata injectors, org-specific tooling
```

- [ ] Integrate secrets scrubber
```yaml
priority: P1
impact: protects journals from leaking tokens/API keys when attaching logs or structured data
steps:
  - provide configurable patterns and allowlist for auto-redaction
  - integrate scrubber into log attachment path (including future `shiplog run` wrapper)
  - add tests to confirm sensitive strings are removed before commit/push
blocked_by: [Design extension/plugin system]
notes:
  - pairs naturally with the plugin architecture; could ship a built-in default scrubber
```

- [ ] Harden docs/plugins.md usage guidance
```yaml
priority: P1
impact: clarify plugin directory semantics for operators
steps:
  - document SHIPLOG_PLUGINS_DIR behavior (auto-create?, relative vs absolute, ~ expansion, permissions, fallback)
  - add absolute/relative path examples and link to troubleshooting for permission errors
blocked_by: []
notes:
  - current docs are incomplete around lines 40–48
```

- [ ] Expand plugin safety guidance
```yaml
priority: P1
impact: make threats and mitigations explicit for plugin authors
steps:
  - enumerate risks (malicious names, traversal, symlinks, privilege escalation)
  - document mitigations (canonical path checks, permissions, code provenance, execution sandboxing, logging)
blocked_by: []
notes:
  - strengthen docs/plugins.md safety notes (lines ~34–38)
```

- [ ] Clarify plugin script contract
```yaml
priority: P1
impact: ensure plugin authors know stderr/timeout/env semantics
steps:
  - specify stderr handling, timeouts, env vars, working dir, stdin format and limits
  - replace unsafe regex example with vetted patterns and add tests covering error paths
blocked_by: []
notes:
  - update docs/plugins.md script interface section (lines ~19–32)
```

- [ ] Deduplicate CI matrix package installs
```yaml
priority: P1
impact: keep distro builds consistent and maintainable
steps:
  - introduce shared package list in ci-matrix/Dockerfile with distro-specific additions
  - document package purpose and retain cleanup commands per distro
blocked_by: []
notes:
  - clean up lines 12–27 in ci-matrix/Dockerfile
```

- [ ] Clarify Ubuntu build args in matrix compose
```yaml
priority: P3
impact: remove confusion in docker-compose.yml for Ubuntu service
steps:
  - add inline comment explaining Ubuntu uses the Debian/apt family
blocked_by: []
notes:
  - adjust ci-matrix/docker-compose.yml lines 16–64
```

- [ ] Align lib/plugins.sh with shell policy
```yaml
priority: P1
impact: ensure plugin loader matches POSIX/guidelines
steps:
  - decide between POSIX-compatible implementation or explicit bash requirement
  - update shebang/directive/docs accordingly and adjust constructs (process substitution, arrays, sort -z)
blocked_by: []
notes:
  - address directives, process substitution, and sorting portability
```

- [ ] Optimize Bosun table parsing
```yaml
priority: P1
impact: faster, portable table rendering
steps:
  - replace split_string loops with localized IFS/read usage for widths and printing
blocked_by: []
notes:
  - refactor sections around rows parsing in scripts/bosun
```

- [ ] Require perl for ANSI stripping
```yaml
priority: P2
impact: predictable Bosun output when perl is missing
steps:
  - fail fast with a clear error if perl is unavailable and update docs to reflect dependency
blocked_by: []
notes:
  - adjust strip_ansi fallback branch in scripts/bosun
```

- [ ] Improve split helper implementation
```yaml
priority: P2
impact: make split_string efficient and localized
steps:
  - use local arrays / readarray approach and document behavior for multi-char delimiters
blocked_by: []
notes:
  - update helper near top of scripts/bosun
```

## Lessons Learned

- Tests that exercise Bosun must run inside the container; native runs may pass even when tab parsing fails under Docker. Always validate UI paths in the same environment CI uses.
- Structured output (Bosun tables) should be constructed column-by-column to avoid shell quoting surprises; use `$'\t'` concatenation rather than embedding literal tabs in a single string.
- Plugin scripts run with full privileges—enforce canonical path checks and clear execution contracts so extensions can’t escape the sandbox. Document the security expectations alongside hooks.

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
