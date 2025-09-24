# GitHub and Shiplog Refs

This guide explains how Shiplog’s Git refs work on GitHub, why you don’t see them in the web UI, and how to protect them using Rulesets.

## Where Shiplog Stores Data

- Shiplog writes commits under custom refs, not branches or tags:
  - Journals: `refs/_shiplog/journal/<env>` (e.g., `prod`)
  - Policy:   `refs/_shiplog/policy/current`
  - Trust:    `refs/_shiplog/trust/root`

GitHub’s web UI only shows branches (`refs/heads/*`) and tags (`refs/tags/*`), so these custom refs won’t appear in the Branches/Tags pages. They do exist on the remote; you can list them with CLI commands.

## Viewing Shiplog Refs on GitHub Repos

- List remote Shiplog refs:
  - `git ls-remote origin 'refs/_shiplog/**'`
- List local Shiplog refs:
  - `git show-ref 'refs/_shiplog/*'`
- Inspect a commit referenced by those refs in the GitHub web UI:
  - Copy the SHA from `ls-remote` and open: `https://github.com/<owner>/<repo>/commit/<SHA>`

## Protecting Shiplog Refs on GitHub

On GitHub.com there are no server-side hooks (like `pre-receive`) for public SaaS repos. Use Rulesets to protect pushes instead.

### Option A — Protect Custom Refs via Push Rulesets (if supported)

Some plans allow rulesets targeting arbitrary ref names. Use a “push” ruleset that includes `refs/_shiplog/**`.

- Target: `push`
- Conditions:
  - `ref_name.include = ["refs/_shiplog/**"]`
- Rules to enable:
  - `deletion`                 (block deletes)
  - `non_fast_forward`         (block force pushes)
  - `creation` and `update`    (ensure pushes go through the ruleset)
  - `required_linear_history`  (keeps history straight)
  - Optional: `required_signatures` (GitHub verification; see caveat below)

Validate:
- Try deleting a journal ref: `git push origin :refs/_shiplog/journal/prod` → should be rejected with a ruleset message.

### Option B — Use Branch Namespace to Leverage Branch Rules

If your plan cannot protect arbitrary refs, move Shiplog refs under branches so Branch Rules can protect them.

- New layout (examples):
  - `refs/heads/_shiplog/journal/<env>`
  - `refs/heads/_shiplog/policy/current`
  - `refs/heads/_shiplog/trust/root`
- Then create a Branch ruleset targeting `_shiplog/**` with the same rules: block deletion, non-FF, require linear history.

Migration sketch:
1) Push current tips to the new namespace:
   - `git for-each-ref 'refs/_shiplog/*' --format='%(refname) %(objectname)' | while read -r ref oid; do new="refs/heads/${ref#refs/}"; git update-ref "$new" "$oid"; done`
   - `git push origin 'refs/heads/_shiplog/*:refs/heads/_shiplog/*'`
2) Point Shiplog at the new root (per repo):
   - `git config shiplog.refRoot 'refs/heads/_shiplog'`
   - or env: `SHIPLOG_REF_ROOT='refs/heads/_shiplog'`
3) Update CI/automation to use the new ref names.

## Switching Ref Root (Toggle Branch vs Custom Refs)

Teams can switch between custom refs (`refs/_shiplog`) and branch namespace (`refs/heads/_shiplog`) per repo. Use the migration helper and update your config.

### One‑shot migration with the helper

```
# Dry run: see what would be mirrored
scripts/shiplog-migrate-ref-root.sh --to refs/heads/_shiplog --dry-run

# Mirror and push the new refs
scripts/shiplog-migrate-ref-root.sh --to refs/heads/_shiplog --push

# (Optional) Remove old refs after mirroring
scripts/shiplog-migrate-ref-root.sh --to refs/heads/_shiplog --remove-old --push
```

Then point Shiplog at the new root for this repo:

```
git config shiplog.refRoot refs/heads/_shiplog
# or per-process:
export SHIPLOG_REF_ROOT=refs/heads/_shiplog
```

To switch back to custom refs, mirror in reverse:

```
scripts/shiplog-migrate-ref-root.sh --from refs/heads/_shiplog --to refs/_shiplog --push
git config shiplog.refRoot refs/_shiplog
```

### Update protection

- Branch namespace: use Branch Rulesets targeting `_shiplog/**`.
- Custom refs: use a Push Ruleset on `refs/_shiplog/**` (if supported), or a required status check that validates Shiplog policy.

## Signatures and Allowed Authors (Caveat)

- GitHub’s `required_signatures` enforces “Verified” signatures tied to users’ GitHub accounts. This is not the same as Shiplog’s trust roster (`allowed_signers`).
- To enforce Shiplog policy (allowed authors, trust-based signatures) on GitHub.com:
  - Use a required status check from CI or a GitHub App that validates pushes against the policy and trust refs, and fails the check when violations occur.
  - Self-hosted Git servers can enforce these checks in `pre-receive` hooks.

## Quick Commands and Checks

- Compare local vs remote journals:
  - `git rev-parse refs/_shiplog/journal/prod`
  - `git ls-remote origin refs/_shiplog/journal/prod`
- Force-refresh local Shiplog refs to match origin (safe for local only):
  - `git fetch origin '+refs/_shiplog/*:refs/_shiplog/*'`
- Show latest entry (human): `git shiplog show`
- JSON only: `git shiplog show --json` (or `--json-compact`)
- NDJSON of all entries: `git shiplog export-json`

## Troubleshooting

- “I don’t see Shiplog refs on GitHub”: expected — they’re custom refs. Use CLI or the GitHub API (`/git/matching-refs/refs/_shiplog/`).
- “Ruleset doesn’t block deletions”: ensure the ruleset targets `push` and includes `refs/_shiplog/**` (not `refs/heads/_shiplog/**`). Branch Target rulesets only protect `refs/heads/*`.
- “Non‑FF still allowed”: enable both `non_fast_forward` and `required_linear_history` in the ruleset.
