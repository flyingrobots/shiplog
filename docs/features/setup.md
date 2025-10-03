# Setup Wizard

The setup wizard helps you choose how strict Shiplog should be for this repository, writes a starter policy, and (optionally) bootstraps trust and pushes refs.

## Usage

```
git shiplog setup \
  [--strictness open|balanced|strict] \
  [--authors "a@x b@y"] \
  [--strict-envs "prod staging"] \
  [--auto-push|--no-auto-push] \
  [--dry-run]

# Non-interactive (env-driven)
SHIPLOG_SETUP_STRICTNESS=balanced \
SHIPLOG_SETUP_STRICT_ENVS="prod staging" \
SHIPLOG_SETUP_AUTHORS="you@example.com teammate@example.com" \
SHIPLOG_SETUP_AUTO_PUSH=1 \
  git shiplog setup

### Choose a Trust Signing Mode (chain vs attestation)

When bootstrapping trust, you can pick how quorum signatures are recorded and verified:

- `chain` — co‑sign chain of commits (pure Git; great with server hooks)
- `attestation` — detached signatures stored under `.shiplog/trust_sigs/` (great for PRs on SaaS hosts)

Set explicitly via flags or env during setup/bootstrap:

```
git shiplog setup --trust-sig-mode chain   # or attestation
SHIPLOG_TRUST_SIG_MODE=attestation git shiplog setup
```

See docs/TRUST.md for details and a comparison.

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
  - Non‑interactive trust bootstrap supported via `SHIPLOG_TRUST_*` env vars (see docs/features/modes.md). The wizard runs the bootstrap script and can auto‑push the trust ref with `--auto-push`.
  - Signing mode: pass `--trust-sig-mode chain|attestation` (default `chain`).

## CLI Trust Bootstrap (No Prompts)

When you want a fully non‑interactive strict setup including trust bootstrap, pass trust details as flags. The setup wrapper will write `.shiplog/policy.json`, sync the local policy ref, then create the trust ref without prompting. It only pushes when `--auto-push` is given.

Example:

```bash
git shiplog setup \
  --strictness strict \
  --trust-id shiplog-trust-root \
  --trust-threshold 2 \
  --trust-maintainer "name=Alice,email=alice@example.com,key=~/.ssh/alice.pub,principal=alice@example.com" \
  --trust-maintainer "name=Bob,email=bob@example.com,key=~/.ssh/bob.pub,principal=bob@example.com" \
  --auto-push
```

Flags (repeat `--trust-maintainer` as needed):
- `--trust-id ID`
- `--trust-threshold N` (≤ number of maintainers)
- `--trust-message "Commit message"` (optional)
- `--trust-maintainer "name=<n>,email=<e>,key=<ssh_pub_path>[,principal=<p>][,role=<r>][,revoked=<yes|no>][,pgp=<fpr>]"`

Notes:
- In CI/non‑TTY: if these flags (or the `SHIPLOG_TRUST_*` envs) are not set, trust bootstrap is skipped for per‑env strictness or fails fast for global strictness instead of prompting.

## Dry Run

- Use `--dry-run` (or `SHIPLOG_SETUP_DRY_RUN=1`) to preview changes to `.shiplog/policy.json` without writing, syncing, or pushing. The wizard shows a semantic no‑op if only formatting changes would occur.

## Auto‑Push

- `--auto-push` (or `SHIPLOG_SETUP_AUTO_PUSH=1`) pushes the policy ref to origin after syncing; `--no-auto-push` disables.
- In Strict mode, if trust was bootstrapped non‑interactively and origin is configured, the wizard also pushes the trust ref.

## Server Guidance

- Install `contrib/hooks/pre-receive.shiplog` on the bare repository to enforce policy and trust.
- During bootstrap, you may set (temporarily) on the hook user:
  - `SHIPLOG_ALLOW_MISSING_POLICY=1`
  - `SHIPLOG_ALLOW_MISSING_TRUST=1`
  See contrib/README.md for details.

## Switching Later

- Use `git shiplog policy require-signed <true|false>` or `git shiplog policy toggle` to flip signing later, then push the policy ref.
- See docs/runbooks/toggle-signing.md for a full runbook.

## Safety: Backups and Diffs

- When updating `.shiplog/policy.json`, the wizard creates a timestamped backup (`.shiplog/policy.json.bak.YYYYMMDDHHMMSS`) and shows a unified diff. If the JSON is semantically unchanged (ignoring formatting or key order), it treats the update as a no‑op to avoid churn.
