CRITICAL: NEVER RUN SHIPLOG LOCALLY - NEVER RUN THE TESTS DIRECTLY
THIS CODE MESSES WITH GIT REPOS AND IF YOU FUCK IT UP YOU WILL
RISK DESTROYING THE ACTUAL GIT REPO ITSELF AND FUCKING UP THIS ENTIRE PROJECT

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

## Testing

- Always run the full test suite before pushing to shared branches
- Use project-defined test commands (e.g., `make test`) rather than running tests directly
- Ensure tests pass in the same environment they'll run in CI/CD

### Project-Specific Notes

- Shiplog tests must run inside Docker via `make test`; never run them directly on the host
- Keep runtime/test dependencies to stock POSIX tools plus `jq`; avoid introducing other external binaries.
