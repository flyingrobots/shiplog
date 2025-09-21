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

- [ ] Extract `.devcontainer` postCreateCommand into `.devcontainer/post-create.sh` and call it from the JSON.
- [ ] Harden `scripts/install-shiplog.sh`: safe `run()`, validate install dir, detect remote default branch, sync `_shiplog/*` fetch.
- [ ] Harden `scripts/uninstall-shiplog.sh`: warn on unpushed refs (`--force` override), safe profile cleanup with Python guard.
- [ ] Refactor `lib/common.sh` JSON escaping/logging helpers.
- [ ] Replace `maybe_sync_shiplog_ref` with robust fetch/push handling and clear errors.
- [ ] Remove legacy `is_boring` fallback in `lib/git.sh` and standardise env vars.
- [ ] Split policy author extraction logic and improve `docs/features/init/verify` plus new schema docs.
- [ ] Improve `scripts/bosun` ANSI stripping, JSON escaping, table parsing.
- [ ] Update `README.md` installer instructions (no `curl|bash`), flag consistency, remove progress bar, adjust feature table evidence.
- [ ] Document uninstaller and auto-push behaviour in README & env vars.
- [ ] Create `.devcontainer/post-create.sh`, make executable.
- [ ] Update CONTRIBUTING docs (`contrib/README.md`) paths for clarity.
- [ ] Add warning about remote refs being preserved.
- [ ] Update test suite:
  - [ ] Simplify count helpers in `test/01_init_and_empty_ls.bats`.
  - [ ] Expand `test/10_boring_mode.bats` assertions for all SHIPLOG_* vars.
  - [ ] Refactor `make_entry` in `test/11_pre_receive_hook.bats` to use locals/clear args.
  - [ ] Remove subshells in `test/13_uninstall.bats` git checks.
  - [ ] Clarify `test/README.md` (image name, sandbox script) and rename MoC header.
- [ ] Adjust README feature table (evidence links or drop Finished column) and policy example (env overrides, schema, semantic version).
- [ ] Update scripts to support canonical `--yes`/`SHIPLOG_ASSUME_YES` naming and remove redundant `--boring` pre-scan.
- [ ] Add JSON schema (`examples/policy.schema.json`) and link in docs/CI.

## Testing

- Always run the full test suite before pushing to shared branches
- Use project-defined test commands (e.g., `make test`) rather than running tests directly
- Ensure tests pass in the same environment they'll run in CI/CD

### Project-Specific Notes

- Shiplog tests must run inside Docker via `make test`; never run them directly on the host

