# Shiplog Environment Variables

This is a compact reference for key `SHIPLOG_*` environment variables. Most can also be set via Git config or CLI flags; see feature docs for details.

## Core

- `SHIPLOG_REF_ROOT` — Root for Shiplog refs
  - Default: `refs/_shiplog`
  - Alternate (branch namespace): `refs/heads/_shiplog`
  - Affects journals/policy/trust/notes ref resolution.

- `SHIPLOG_POLICY_REF` — Policy ref (JSON file lives at `.shiplog/policy.json` inside the ref)
  - Default: `refs/_shiplog/policy/current`

- `SHIPLOG_TRUST_REF` — Trust ref (tree with `.shiplog/trust.json` and `.shiplog/allowed_signers`)
  - Default: `refs/_shiplog/trust/root`

- `SHIPLOG_NOTES_REF` — Git notes ref for attached logs (NDJSON)
  - Default: `refs/_shiplog/notes/logs`

- `SHIPLOG_ENV` — Default journal environment when omitted on commands
  - Default: `prod`

- `SHIPLOG_AUTO_PUSH` — Auto-push Shiplog refs to `origin` when available (`write`, some `setup` flows)
  - Values: `1` (default) or `0`

- `SHIPLOG_BORING` — Non-interactive/plain mode (disables Bosun UI)
  - Values: `1` or `0` (default)

- `SHIPLOG_ASSUME_YES` — Auto-confirm prompts (same as `--yes`)
  - Values: `1` or `0` (default)

## Policy & Signing

- `SHIPLOG_AUTHORS` — Space-separated allowlist of authors (emails). Overrides policy.
- `SHIPLOG_ALLOWED_SIGNERS` — Path to allowed signers file (SSH). Overrides policy.
- `SHIPLOG_SIGN` — Require signing for `write` operations in this session (policy may still require it).
  - Values: `1` or `0` (default)

## Write Inputs (non-interactive)

- `SHIPLOG_SERVICE`, `SHIPLOG_STATUS`, `SHIPLOG_REASON`, `SHIPLOG_TICKET`
- `SHIPLOG_REGION`, `SHIPLOG_CLUSTER`, `SHIPLOG_NAMESPACE`
- `SHIPLOG_IMAGE`, `SHIPLOG_TAG`, `SHIPLOG_RUN_URL`
- `SHIPLOG_LOG` — Path to NDJSON log to attach as a git note
- `SHIPLOG_EXTRA_JSON` — Raw JSON object merged into the structured trailer (set automatically by `git shiplog run`)

See: docs/features/write.md for full semantics and examples.

## Setup Wizard (non-interactive)

- `SHIPLOG_SETUP_STRICTNESS` — `open` | `balanced` | `strict`
- `SHIPLOG_SETUP_STRICT_ENVS` — Space-separated envs for per-env strictness (strict only)
- `SHIPLOG_SETUP_AUTHORS` — Space-separated emails for allowlist (balanced)
- `SHIPLOG_SETUP_AUTO_PUSH` — `1` to push policy/trust to origin
- `SHIPLOG_SETUP_DRY_RUN` — `1` to preview without writing/syncing

## Trust Bootstrap (non-interactive)

- `SHIPLOG_TRUST_COUNT`, `SHIPLOG_TRUST_ID`, `SHIPLOG_TRUST_THRESHOLD`, `SHIPLOG_TRUST_COMMIT_MESSAGE`
- Per-maintainer fields (1..N):
  - `SHIPLOG_TRUST_<i>_NAME`, `SHIPLOG_TRUST_<i>_EMAIL`, `SHIPLOG_TRUST_<i>_ROLE`
  - `SHIPLOG_TRUST_<i>_PGP_FPR` (optional)
  - `SHIPLOG_TRUST_<i>_SSH_KEY_PATH` (path to public key)
  - `SHIPLOG_TRUST_<i>_PRINCIPAL` (SSH principal; defaults to email)
  - `SHIPLOG_TRUST_<i>_REVOKED` (yes/no)

## CI/Tests

- `TEST_TIMEOUT_SECS` — In-container Bats timeout (seconds). Default: `180`.
- `BATS_FLAGS` — Extra flags for Bats (e.g., `--print-output-on-failure -T`).
- `SHIPLOG_USE_LOCAL_SANDBOX` — `1` to avoid network clones in tests (default `1`).
