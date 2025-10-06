{
  "id": "SLT.ALPHA.020",
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
    "Partially implemented: CLI 'policy validate' exists; AJV step added (non-blocking). This task tracks final alignment and gating decision."
  ],
  "created": "2025-10-03",
  "updated": "2025-10-06",
  "estimate": "med",
  "expected_complexity": "medium"
}

