# Shiplog Contrib

Supporting assets that help you wire Shiplog into a larger deployment workflow.

## Hooks

- `hooks/pre-receive.shiplog` – sample server-side guard that enforces (requires: git ≥2.35, jq ≥1.6, yq v4.x by mikefarah, bash):
  - fast-forward pushes to `refs/_shiplog/journal/*` and `refs/_shiplog/anchors/*`
  - commit signatures (GPG or SSH allowed signers)
  - author allowlists pulled from the active policy

To install on a bare repository:

```bash
cp contrib/hooks/pre-receive.shiplog /path/to/bare.git/hooks/pre-receive
chmod +x /path/to/bare.git/hooks/pre-receive
```

The hook expects the policy file under `refs/_shiplog/policy/current`. The `.shiplog/policy.yaml` fallback is for local/dev only; do NOT rely on it in production repositories.
## CI Helpers

- `../scripts/shiplog-sync-policy.sh` – creates a fast-forward signed commit for the policy ref (does not push). Run this from CI after merging the policy change branch, then push:

## Policy Templates

- `../examples/policy.yaml` – starter policy you can copy into `.shiplog/policy.yaml` before publishing with the sync script.

## Suggested Workflow

1. Update `.shiplog/policy.yaml` in a branch.
2. Run `scripts/shiplog-sync-policy.sh` (in CI or locally) after merge to bump `refs/_shiplog/policy/current`.
3. The pre-receive hook validates writes to the Shiplog refs using that policy.

Feel free to adapt these assets to match your infrastructure (GitHub, GitLab, Gitea, etc.).
