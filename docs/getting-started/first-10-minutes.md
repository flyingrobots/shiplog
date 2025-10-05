# First 10 Minutes with Shiplog

This quickstart gets you from zero to your first Shiplog entry with safe, host‑aware defaults.

## 1) Install

```bash
git clone https://github.com/flyingrobots/shiplog.git "$HOME/.shiplog"
export SHIPLOG_HOME="$HOME/.shiplog" && export PATH="$SHIPLOG_HOME/bin:$PATH"
"$SHIPLOG_HOME/install-shiplog-deps.sh"
```

Verify:

```bash
git shiplog --version
```

## 2) Pick Host‑Aware Defaults

```bash
# Prints a plan JSON; add --apply to write policy/config
git shiplog config --interactive
# Or apply locally
git shiplog config --interactive --apply
```

Tips:
- SaaS (GitHub.com, GitLab.com, Bitbucket.org): prefer branch namespace and add Required Checks.
- Self‑hosted: install server hooks. See docs/hosting/matrix.md and docs/hosting/github.md.

## 3) Make Your First Entry

```bash
export SHIPLOG_ENV=prod SHIPLOG_SERVICE=web
# Interactive
git shiplog write
# Or append via JSON
printf '{"checks":{"smoke":"green"}}' | git shiplog append --service web --status success --json -
```

Tip (non‑interactive/CI): pass required fields via flags or env so prompts are not needed. For example:

```bash
SHIPLOG_ENV=prod SHIPLOG_SERVICE=web \
  git shiplog --boring --yes write --status success --reason "first run"

# or use append with JSON payload (no prompts)
printf '{"checks":{"smoke":"green"}}' | \
  git shiplog append --service web --status success --json -
```

## 4) Inspect

```bash
git shiplog ls --env prod
git shiplog show --json-compact
```

## 5) Publish (Optional)

If you disabled auto‑push during deploys, publish explicitly at the end:

```bash
git shiplog publish --env prod
```

Next steps:
- Choose trust signing mode (chain vs attestation) and threshold: docs/TRUST.md.
- Add CI checks and (if using branch namespace) import Rulesets: docs/hosting/matrix.md.
