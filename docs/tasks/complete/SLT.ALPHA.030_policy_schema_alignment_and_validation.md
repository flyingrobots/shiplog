{
  "id": "SLT.ALPHA.030",
  "labels": ["policy", "schema", "ci", "docs"],
  "milestone": "Alpha",
  "name": "Align policy schema, writers, and CI validation",
  "description": "Make the policy schema authoritative or trim it to the enforced subset. Update writers to emit the chosen shape, keep AJV in CI (potentially gating), and document the final spec.",
  "priority": "P2",
  "impact": "Eliminates drift between docs/schema/CLI; consistent validation.",
  "steps": [
    "Decide schema shape (full vs minimal)",
    "Update examples/policy.schema.json and docs/policy.md",
    "Update CLI writers to emit compliant JSON",
    "Evaluate making AJV gating when policy paths change"
  ],
  "blocked_by": [],
  "notes": [
    "2025-10-09: Trimmed schema to enforced fields, expanded CLI validation, updated docs, and gated Ajv on policy-path PRs."
  ],
  "created": "2025-10-03",
  "updated": "2025-10-09",
  "estimate": "med",
  "expected_complexity": "medium"
}
