# Policy Resolution

## Summary
Shiplog layers policy data from several sources to produce the effective allowlist, signing requirements, and ref locations used by every command. Resolution happens in a strict precedence order so you can keep long-lived rules in Git while allowing local overrides for testing. `git shiplog policy` prints the merged result (and its source) so operators can audit what will be enforced.

## Usage
```bash
git shiplog policy [show|validate] [--boring|--json]
git shiplog policy require-signed <true|false>
git shiplog policy toggle
```

## Resolution Order
Shiplog evaluates inputs in the following order (higher entries win when they provide a value):
1. CLI flags / environment overrides (`SHIPLOG_AUTHORS`, `SHIPLOG_ALLOWED_SIGNERS`, `SHIPLOG_SIGN`).
2. Repository Git configuration (`shiplog.policy.allowedAuthors`, `shiplog.policy.allowedSignersFile`, `shiplog.policy.requireSigned`).
3. Policy commit referenced by `refs/_shiplog/policy/current` (default) or the ref supplied via `SHIPLOG_POLICY_REF`/`--policy-ref`.
4. Working-tree fallback `.shiplog/policy.json`.
5. Built-in defaults (signing disabled, authors unrestricted, notes ref `refs/_shiplog/notes/logs`).

### Merge Rules
- **Authors**: the policy union merges `authors.default_allowlist`, `authors.env_overrides.default`, and `authors.env_overrides[ENV]` (duplicates removed). CLI env or Git config supply a complete replacement rather than merging.
- **Signing requirement**: the first source that specifies a boolean wins (`true` requires signatures). CLI/Git config allow temporary overrides for local runs.
- **Signer files / refs**: policy paths override Git config/env; otherwise the repo-relative `.shiplog/allowed_signers` and default ref prefixes apply.

### Example Effective Policy
With `ENV=prod`, no overrides, and a populated policy ref:
```
Source: policy-ref:refs/_shiplog/policy/current
Require Signed: enabled
Allowed Authors: deploy-bot@ci ops@example.com
Allowed Signers File: /repo/.shiplog/allowed_signers
Notes Ref: refs/_shiplog/notes/logs
```

Run `git shiplog policy --boring` for plain-text output or `--json` to integrate with tooling.

## Policy File Examples

### Minimal policy.json
```json
{
  "version": "1.0.0",
  "authors": {
    "default_allowlist": ["deploy@example.com"]
  }
}
```

### Fuller policy with environment overrides
```json
{
  "version": "1.0.0",
  "schema": "../examples/policy.schema.json",
  "allow_ssh_signers_file": "~/.shiplog/allowed_signers",
  "authors": {
    "default_allowlist": ["deploy-bot@ci", "releases@example.com"],
    "env_overrides": {
      "prod": ["lead@example.com", "sre@example.com"],
      "staging": ["qa@example.com"]
    }
  },
  "deployment_requirements": {
    "default": {
      "require_ticket": false
    },
    "prod": {
      "require_signed": true,
      "require_ticket": true,
      "require_service": true,
      "require_where": ["region", "cluster", "namespace"]
    },
    "staging": {
      "require_signed": false
    }
  },
  "notes_ref": "refs/_shiplog/notes/logs",
  "journals_ref_prefix": "refs/_shiplog/journal/",
  "anchors_ref_prefix": "refs/_shiplog/anchors/"
}
```

The JSON Schema that validates these files lives at `examples/policy.schema.json`.

### Validating policies
```bash
# Syntax check
jq '.' .shiplog/policy.json >/dev/null

# Schema validation with ajv
npm install -g ajv-cli
ajv validate --spec=draft2020 --schema examples/policy.schema.json --data .shiplog/policy.json
```

## Override Mapping
| Setting | CLI / Env | Git Config | Policy Field |
|---------|-----------|------------|--------------|
| Allowed authors | `SHIPLOG_AUTHORS` | `shiplog.policy.allowedAuthors` | `authors.*` |
| Allowed signers file | `SHIPLOG_ALLOWED_SIGNERS` | `shiplog.policy.allowedSignersFile` | `allow_ssh_signers_file` |
| Require signed commits | `SHIPLOG_SIGN` | `shiplog.policy.requireSigned` | `require_signed` |

## Related Code
- `lib/policy.sh:3`
- `lib/commands.sh:142`

## Tests
- `test/09_policy_resolution.bats:25`
