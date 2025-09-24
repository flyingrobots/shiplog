# GitHub Ruleset Examples for Shiplog

GitHub’s Rulesets UI supports JSON import/export, but only for branch/tag rules. It does not support matching custom refs (like `refs/_shiplog/**`). If you want UI‑managed protection for Shiplog, use the branch namespace (`refs/heads/_shiplog/**`).

Files in this folder are example Rulesets you can import via:

Settings → Rules → Rulesets → New ruleset → Import from JSON

Notes:
- These examples target branches under `_shiplog/**`. They assume you’ve migrated Shiplog to branch namespace (see docs/hosting/github.md).
- `required_signatures` uses GitHub Account‑verified signatures (GPG/SSH). It does not enforce Shiplog trust/allowed signers.
- To enforce Shiplog policy (allowed authors, trust-based signatures), add a required status check that runs verification in CI or use a GitHub App.

Files:
- `ruleset-branch-shiplog-protect.json`: Protects `_shiplog/**` branches against deletion and non‑FF, requires linear history, and allows creation/update.
- `ruleset-branch-shiplog-restricted.json`: Same as above plus an example of restricting who can push.

