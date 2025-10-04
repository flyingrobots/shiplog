## 🚢🪵 Shiplog — Git‑Native Deployment Ledger

Your deployment history should live next to your code. No SaaS. No secrets. Just Git doing what Git does best: immutable, replicated history with cryptographic integrity.

—

## Why Shiplog

- Single source of truth: deployments, rollbacks, hotfixes, and ops events become signed Git records.
- Human + JSON: readable TTY views and script‑friendly output (`--json|--json-compact|--jsonl`).
- Trust & policy in Git: quorum‑guarded policy; allowlists; optional signature gates.
- Zero new infra: uses refs under your repo; works offline; mirrors automatically via Git.

—

## Quick Start

Install once on your workstation or CI runner:

```bash
git clone https://github.com/flyingrobots/shiplog.git "$HOME/.shiplog"
export SHIPLOG_HOME="$HOME/.shiplog" && export PATH="$SHIPLOG_HOME/bin:$PATH"
"$SHIPLOG_HOME/install-shiplog-deps.sh"
git shiplog --version
```

Initialize in a repo and record the first entry:

```bash
cd your-repo
git shiplog init
export SHIPLOG_ENV=prod SHIPLOG_SERVICE=web
git shiplog write   # prompts for metadata; respects policy allowlists

# Optional: publish refs explicitly (see Auto‑push & Publish below)
git shiplog publish --env prod
```

Optionally, run the config wizard to pick host‑aware defaults:

```bash
git shiplog config --interactive   # prints a plan; add --apply to write policy/config
```

Inspect history (human + JSON):

```bash
git shiplog ls --env prod
git shiplog show --json-compact   # single entry JSON
git shiplog export-json           # NDJSON stream
```

Wrap a command and capture its logs:

```bash
git shiplog run --service deploy --reason "canary" -- \
  kubectl rollout status deploy/web
# prints a minimal confirmation (default "🪵"); set SHIPLOG_CONFIRM_TEXT to override
```

—

## Core Concepts

- Refs (where data lives)
  - Journals: `refs/_shiplog/journal/<env>`
  - Policy:   `refs/_shiplog/policy/current`
  - Trust:    `refs/_shiplog/trust/root`
- Policy as code: required fields, allowlists per env, signature requirements. See docs/features/policy.md and docs/TRUST.md.
- Environments: each environment has its own append‑only journal (fast‑forward only).

—

## Trust Modes (Multi‑Sig)

Choose how maintainer approval is expressed. Both are supported; pick per‑repo during setup.

- Chain (sig_mode=chain)
  - What: maintainers sign trust commits; threshold distinct signers over the evolving trust tree.
  - Pros: Git‑native flow; familiar commit signatures; great audit trail.
  - Cons: requires signing trust commits (often via a maintainer workflow).

- Attestation (sig_mode=attestation)
  - What: maintainers sign a canonical payload (tree OID + context) and attach signatures; verified via `ssh-keygen -Y verify`.
  - Pros: flexible; easy to automate with SSH keys; decouples signatures from trust commit authoring.
  - Cons: extra artifact management; be precise about canonicalization.

Fast pick:
- Prefer chain if maintainers are comfortable signing Git commits.
- Prefer attestation if you already manage SSH keys for approvals or want signatures produced outside Git.

See docs/TRUST.md for bootstrapping and scripts.

—

## Git Hosts & Enforcement

- GitHub.com (SaaS): no custom server hooks. Use Branch/Push Rulesets and Required Status Checks. For strong protections on SaaS, use branch namespace (`refs/heads/_shiplog/**`) so branch rules can protect your Shiplog refs. See docs/hosting/github.md.
- Self‑hosted (GH Enterprise, GitLab self‑managed, Gitea, Bitbucket DC): install the pre‑receive hook (`contrib/hooks/pre-receive.shiplog`) and enforce trust/policy server‑side.
- Matrix & recipes: see docs/hosting/matrix.md for a side‑by‑side of capabilities and recommended configs.

Switching namespaces is supported (custom refs ↔ branch namespace) via scripts/shiplog-migrate-ref-root.sh and `git config shiplog.refRoot`.

—

## Auto‑push & Publish

To avoid tripping pre‑push hooks mid‑deploy, Shiplog separates writing from publishing. Control behavior via flags, repo config, or env:

- Precedence: command flags > `git config shiplog.autoPush` > environment/default.
- Explicit publish: `git shiplog publish [--env <env>|--all] [--no-notes] [--policy] [--trust]`.

Examples:
- Disable auto‑push per repo: `git config shiplog.autoPush false`; publish at the end of a deploy: `git shiplog publish --env prod`.
- Force publish for one command: `git shiplog write --push` (overrides config).

—

## Output UX

- Minimal confirmations: `git shiplog run` prints emoji‑only by default (🪵). Set `SHIPLOG_CONFIRM_TEXT` for a plain alternative (e.g., `> Shiplogged`).
- Clean headers: optional fields are hidden rather than shown as `?`.

—

## What’s Live vs Roadmap

Live now
- Journals (append‑only by env) with human and JSON views.
- Policy and trust refs; allowlists per env; threshold‑based verification.
- Two trust modes (chain, attestation) and a shared verifier script.
- `run`, `write`, `append`, `ls`, `show`, `export-json`, `publish`.
- GitHub SaaS guidance + self‑hosted hook; hosting matrix docs.
- Dockerized cross‑distro test matrix; lint workflows (shell, markdown, yaml).

On the roadmap
- Interactive “Setup Questionnaire” to recommend trust mode, thresholds, namespace, CI checks, and rulesets (see docs/tasks/backlog/SLT.BETA.020_setup_questionnaire.md).
- More end‑to‑end tests for attestation verification across distros.
- Flip linters to blocking once baseline is clean.

—

## Upgrading

See RELEASE_NOTES.md for version‑specific guidance and any one‑time steps (e.g., ref namespace changes, publish defaults, or trust signature gates such as `SHIPLOG_REQUIRE_SIGNED_TRUST`).

—

## Contributing & Tests

- Please read AGENTS.md before running tests or editing hooks/scripts.
- Run tests only via Docker: `make test` (and `TEST_TIMEOUT_SECS=180 make test` to guard hangs). Do not run Bats directly on your host.

—

## License

MIT © J. Kirby Ross (@flyingrobots)

Jenkins was not harmed in the making of this project.
