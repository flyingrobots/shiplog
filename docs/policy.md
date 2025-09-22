# Shiplog Policy Reference

This document summarizes the fields accepted by `.shiplog/policy.json`. A formal JSON Schema is published at [`examples/policy.schema.json`](../examples/policy.schema.json). Validate changes locally with:

```bash
# Syntax check
jq '.' .shiplog/policy.json >/dev/null

# Schema validation (choose one)
npm install -g ajv-cli
ajv validate --spec=draft2020 --schema examples/policy.schema.json --data .shiplog/policy.json

pip install jsonschema
python -m jsonschema -i .shiplog/policy.json examples/policy.schema.json
```

## Top-level Fields

| Field | Type | Description |
|-------|------|-------------|
| `schema` | string | Optional URI reference to the JSON Schema used for validation (e.g., "https://example.com/policy.schema.json"). |
| `version` | string (`major.minor.patch`) | Policy format version (e.g., `1.0.0`). |
| `format_compat` | string | Semantic version range indicating compatible policy parsers (e.g., ">=1.0.0 <2.0.0"). |
| `require_signed` | boolean | Require signatures for journal entries. |
| `allow_ssh_signers_file` | string | Path to SSH allowed signers file (relative paths resolve from repo root). |
| `authors` | object | Defines which email addresses are permitted to author shiplog entries, with optional per-environment overrides. |
| `deployment_requirements` | object | Per-environment guardrails for Shiplog entries. |
| `ff_only` | boolean | Enforce fast-forward updates to Shiplog refs. |
| `notes_ref` | string | Git notes ref storing log attachments. |
| `journals_ref_prefix` | string | Prefix for journal refs (usually `refs/_shiplog/journal/`). |
| `anchors_ref_prefix` | string | Prefix for anchor refs (usually `refs/_shiplog/anchors/`). |
## Authors

```json
"authors": {
  "default_allowlist": [
    "deploy-bot@ci",
    "releases@example.com"
  ],
  "env_overrides": {
    "prod": ["lead@example.com", "sre@example.com"],
    "staging": ["qa@example.com"],
    "default": ["dev@example.com"]
  }
}
```

- `default_allowlist`: baseline set of permitted author emails.
- `env_overrides`: per-environment author lists that are ADDED to (not replacing) the default_allowlist. Final allowlist = default_allowlist + env_overrides[environment], deduplicated.

## Deployment Requirements

Each key under `deployment_requirements` corresponds to an environment name (e.g., `prod`, `staging`, `default`). The object supports:

| Field | Type | Description |
|-------|------|-------------|
| `require_ticket` | boolean | Require a ticket identifier in Shiplog entries. |
| `require_service` | boolean | Require the service field to be present. |
| `require_where` | array | Require specific `where` attributes (allowed values: `region`, `cluster`, `namespace`, `service`, `environment`). |

Missing fields inherit from the `default` entry when present.

## Validation Tips

- Run `ajv validate -s examples/policy.schema.json -d .shiplog/policy.json` in CI to block invalid policies.
- If `require_signed` is `true`, ensure `allow_ssh_signers_file` exists and is readable by automation.
- Keep semantic versioning consistent to signal breaking policy format changes.
