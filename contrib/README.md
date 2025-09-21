# Shiplog Contrib

Supporting assets that help you wire Shiplog into a larger deployment workflow.

## Hooks

- `hooks/pre-receive.shiplog` – sample server-side guard that enforces (requires: git ≥2.35, jq ≥1.6, bash):
  - fast-forward pushes to `refs/_shiplog/journal/*` and `refs/_shiplog/anchors/*`
  - commit signatures (GPG or SSH allowed signers)
  - author allowlists pulled from the active policy

To install on a bare repository:

#!/bin/bash
set -euo pipefail

if [[ ! -f "contrib/hooks/pre-receive.shiplog" ]]; then
  echo "Error: contrib/hooks/pre-receive.shiplog not found" >&2
  exit 1
fi

cp contrib/hooks/pre-receive.shiplog /path/to/bare.git/hooks/pre-receive
chmod +x /path/to/bare.git/hooks/pre-receive
echo "Hook installed successfully"

The hook expects the policy file to be available under `refs/_shiplog/policy/current` and will fall back to `.shiplog/policy.json` if the ref is absent.

## CI Helpers

- `../scripts/shiplog-sync-policy.sh` – publishes `.shiplog/policy.json` to the policy ref as a fast-forward signed commit (does not push). Run this from CI after merging the policy change branch, then push the ref:

```bash
scripts/shiplog-sync-policy.sh
git push origin refs/_shiplog/policy/current
```

## Policy Templates

- `../examples/policy.json` – starter policy you can copy into `.shiplog/policy.json` before publishing with the sync script.

## Suggested Workflow

1. Update `.shiplog/policy.json` in a branch.
2. Run `scripts/shiplog-sync-policy.sh` (in CI or locally) after merge to bump `refs/_shiplog/policy/current`.
3. The pre-receive hook validates writes to the Shiplog refs using that policy.

Feel free to adapt these assets to match your infrastructure (GitHub, GitLab, Gitea, etc.).
