# Setup Wizard

The setup wizard helps you choose how strict Shiplog should be for this repository, writes a starter policy, and (optionally) bootstraps trust and pushes refs.

## Usage

```
git shiplog setup [--auto-push] [--strict-envs "prod staging"] [--authors "a@x b@y"] [--dry-run]

# Non-interactive (env-driven)
SHIPLOG_SETUP_STRICTNESS=open|balanced|strict \
SHIPLOG_SETUP_STRICT_ENVS="prod staging" \
SHIPLOG_SETUP_AUTHORS="you@example.com teammate@example.com" \
SHIPLOG_SETUP_AUTO_PUSH=1 \
  git shiplog setup --auto-push --strict-envs "prod staging" --authors "you@example.com teammate@example.com"
```

## Modes

- Open (unsigned):
  - Policy: `require_signed=false`.
  - Use when adopting Shiplog quickly or experimenting.

- Balanced (unsigned + allowlist):
  - Policy: `require_signed=false`, with `authors.default_allowlist` populated.
  - Wizard includes your current `git config user.email` and any emails from `SHIPLOG_SETUP_AUTHORS`.

- Strict (signed):
  - Global strict: `require_signed=true` for all environments.
  - Per‑environment strict: `require_signed=false` globally and `deployment_requirements.<env>.require_signed=true` for selected envs (e.g., prod only).
  - Non‑interactive trust bootstrap supported via `SHIPLOG_TRUST_*` env vars (see docs/features/modes.md:1). The wizard runs the bootstrap script and can auto‑push the trust ref with `--auto-push`.

## Dry Run

- Use `--dry-run` (or `SHIPLOG_SETUP_DRY_RUN=1`) to preview changes to `.shiplog/policy.json` without writing, syncing, or pushing. The wizard prints a unified diff (or a full file preview if creating fresh).

## Auto‑Push

- `--auto-push` (or `SHIPLOG_SETUP_AUTO_PUSH=1`) pushes the policy ref to origin after syncing.
- In Strict mode, if trust was bootstrapped non‑interactively and origin is configured, the wizard also pushes the trust ref.

## Server Guidance

- Install `contrib/hooks/pre-receive.shiplog` on the bare repository to enforce policy and trust.
- During bootstrap, you may set (temporarily) on the hook user:
  - `SHIPLOG_ALLOW_MISSING_POLICY=1`
  - `SHIPLOG_ALLOW_MISSING_TRUST=1`
  See contrib/README.md for details.

## Switching Later

- Use `git shiplog policy require-signed <true|false>` or `git shiplog policy toggle` to flip signing later, then push the policy ref.
- See docs/runbooks/toggle-signing.md:1 for a full runbook.

## Safety: Backups and Diffs

- When the wizard updates an existing `.shiplog/policy.json`, it creates a timestamped backup (`.shiplog/policy.json.bak.YYYYMMDDHHMMSS`) and shows a unified diff of changes. If there’s no change, it says so and leaves the file untouched.
