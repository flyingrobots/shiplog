{
  "id": "SLT.ALPHA.020",
  "labels": ["policy", "schema", "ci", "docs"],
  "milestone": "Alpha",
  "name": "Align policy schema, writers, and CI validation",
  "description": "Make the policy schema authoritative or trim it to the enforced subset. Update writers (setup, policy require-signed) to emit the chosen shape, adopt AJV validation in CI, and make jq-based validation optional only inside containers.",
  "priority": "P2",
  "impact": "Eliminates confusion and failures from schema/doc drift; ensures policies are validated consistently.",
  "steps": [
    "Decide schema direction: full semver/object vs minimal numeric version",
    "Update examples/policy.schema.json and docs/policy.md to match",
    "Update CLI writers to emit compliant JSON",
    "Add CI job using ajv-cli to validate .shiplog/policy.json",
    "Make scripts/shiplog-sync-policy.sh surface validation errors clearly"
  ],
  "blocked_by": [],
  "notes": ["Prefer ajv in CI; keep jq --schema only when available in containers"],
  "created": "2025-10-03",
  "updated": "2025-10-03",
  "estimate": "med",
  "expected_complexity": "medium"
}

