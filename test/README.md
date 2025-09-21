# Shiplog Test Suite

## MoC
- [Overview](#overview)
- [Test Runner](#test-runner)
- [Adding or Updating Tests](#adding-or-updating-tests)
- [Running Specific Tests](#running-specific-tests)
- [Troubleshooting](#troubleshooting)

## Overview
The `test/` directory contains the Bats-based integration suite that exercises the Shiplog CLI via the `git shiplog` porcelain. Each file ending in `.bats` is automatically picked up by the Docker test harness, and helper scripts live under `test/helpers/`.

## Test Runner
- `make test` builds the local Docker image (if needed) and runs all Bats files with signing disabled. The container mounts the workspace at `/workspace` and executes `/usr/local/bin/run-tests`.
- `make test-signing` performs the same flow with `ENABLE_SIGNING=true`, generating a throwaway GPG key inside the container so commits are signed before verification.
- The Docker entrypoint installs `bin/git-shiplog` into `/usr/local/bin/git-shiplog`, generates a non-interactive gum stub, and then calls `bats -r /workspace/test`.
- Each Bats file calls `load helpers/common`, whose `shiplog_install_cli` helper ensures the CLI is present and executable before tests begin.

## Adding or Updating Tests
1. Create a new `*.bats` file or update an existing one under `test/`.
2. Reuse shared setup logic via `load helpers/common` and environment variables (`SHIPLOG_*`) rather than duplicating installation code.
3. Use the global `--yes` flag instead of piping `yes |` when a test needs to auto-accept prompts.
4. Keep tests hermetic: they should initialize their own temporary repos, configure required policy files, and avoid relying on host state.
5. Document new scenarios by updating `docs/features/` or the README feature table so tooling stays in sync.

## Running Specific Tests
- To run a single test file inside Docker: `docker run --rm -v "$PWD":/workspace shiplog-tests bats test/05_verify_authors.bats` (build the image first with `make build`).
- To run a specific test case interactively, drop into the sandbox container (`./shiplog-sandbox.sh`) and execute `bats test/<file>.bats -f '<test name pattern>'`.
- Always run tests inside Docker; host execution is unsupported and may skip required setup.

## Troubleshooting
- If you see this error:
