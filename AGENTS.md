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

- [x] Extract `.devcontainer` postCreateCommand into `.devcontainer/post-create.sh` and call it from the JSON.
- [x] Harden `scripts/install-shiplog.sh`: safe `run()`, validate install dir, detect remote default branch, sync `_shiplog/*` fetch.
- [x] Harden `scripts/uninstall-shiplog.sh`: warn on unpushed refs (`--force` override), safe profile cleanup with Python guard.
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
- [ ] Replace the `gum` dependency with `scripts/bosun`.
- [x] Investigate and fix the failing Dockerized test suite after the CLI/runtime changes.
- [ ] Re-enable pre-receive hook tests once we can exercise the Git server path without SSH.
- [x] Restore the signing test when reliable GPG automation exists in CI.
- [ ] Wire `git shiplog` subcommands to `scripts/bosun` instead of `gum`, and delete the gum stub.
- [ ] Swap installer/uninstaller/README references from gum to bosun and drop gum from the Docker image.
- [ ] Harden `scripts/bosun` (ANSI stripping, quoting) until ShellCheck passes and the CI parser error disappears.
- [ ] Build a non-SSH hook harness (e.g., local exec transport) and unskip the three pre-receive tests.
- [ ] Document the signing workflow (loopback wrapper, allowed signers) in README + docs/features, and add failing-path tests.
- [ ] Align ShellCheck across scripts (bin/git-shiplog globals, install script printf) so the lint run is warning-free or explicitly suppressed.
- [ ] Update Docker test harness to work on a copied repo snapshot (no bind mount) and ensure tests create isolated git remotes.
- [ ] Prevent tests from mutating real remotes (introduce throw-away test repos instead of in-place git config edits).
- [ ] docs/bosun/choose.md — add an interactive example showing menu prompt, user input, and output.
- [ ] docs/bosun/confirm.md — normalize examples (consistent comments, JSON formatting, decline scenario + exit codes).
- [ ] docs/bosun/input.md — add edge-case examples (empty stdin, non-tty behaviour, placeholder+default) with outputs/exit codes.
- [ ] docs/bosun/overview.md — expand each command description with purpose, flags, defaults, and a concise example.
- [ ] docs/features/init.md — clarify the `core.logAllRefUpdates` explanation with concrete behaviour and implications.
- [ ] docs/features/ls.md — document ENV parameter and add multiple usage examples.
- [ ] docs/features/policy.md — replace buzzwords with explicit precedence rules, add minimal + full policy examples, schema reference, override mapping.
- [ ] docs/features/write.md — enumerate all supported `SHIPLOG_*` env vars (purpose, type, defaults, examples).
- [ ] docs/policy.md — correct validation guidance, provide full authors JSON example, note schema/override usage.
- [ ] examples/policy.json — resolve signers file path deterministically (absolute/homedir) and adjust docs.
- [ ] examples/policy.schema.json — tighten Git ref regex validation for notes/prefix fields.
- [ ] lib/commands.sh — remove ensure_config_value helper and refactor maybe_sync_shiplog_ref via new helper functions; simplify artifact construction.
- [ ] lib/common.sh — improve JSON escaping fallback (or require jq), validate env var names/blacklist, refactor prompt helpers, add logging helper.
- [ ] lib/git.sh — source common.sh explicitly, enable strict mode, standardize gum fallback messaging.
- [ ] lib/policy.sh — restore default sign behaviour, refactor parsing helpers, improve authors jq aggregation, resolve signers path robustly.
- [ ] scripts/bosun — validate BOSUN_DOC_ROOT, unify ANSI stripping implementation, replace naive CSV/TSV parsing with robust parser.
- [ ] scripts/install-shiplog.sh — replace embedded Python path resolver with shell realpath/readlink logic.
- [ ] scripts/uninstall-shiplog.sh — extract Python cleanup to standalone script or shell alternative per review comments.
- [ ] scripts/shiplog-sync-policy.sh — replace fragile grep-based schema detection per review feedback.
- [ ] test/01_init_and_empty_ls.bats — add backup/restore of git config before mutation.
- [ ] test/02_write_and_ls_show.bats — add trailer/jq helper functions and remove manual parsing; fail when jq missing.
- [ ] test/09_policy_resolution.bats — dedupe policy setup helper and add edge-case tests for invalid policy scenarios.
- [ ] test/11_pre_receive_hook.bats — stabilize error messages, handle REMOTE_DIR safely, unskip/cleanup tests properly.
- [ ] test/13_uninstall.bats — switch to temp bin dir, guard git config assertions, restore remote configs reliably.
- [ ] test/helpers/common.bash — simplify shiplog_install_cli checks or provide actionable guidance per review.

## Testing

- Always run the full test suite before pushing to shared branches
- Use project-defined test commands (e.g., `make test`) rather than running tests directly
- Ensure tests pass in the same environment they'll run in CI/CD

### Project-Specific Notes

- Shiplog tests must run inside Docker via `make test`; never run them directly on the host
- Keep runtime/test dependencies to stock POSIX tools plus `jq`; avoid introducing other external binaries.
