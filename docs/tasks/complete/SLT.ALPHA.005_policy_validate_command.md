{
  "id": "SLT.ALPHA.005",
  "labels": ["cli", "policy"],
  "milestone": "Alpha",
  "name": "Policy validate command",
  "description": "Add `git shiplog policy validate` with jq-based structural checks for the working .shiplog/policy.json.",
  "priority": "P2",
  "impact": "catches broken policy before publish",
  "steps": [
    "Implement structural checks and pretty errors",
    "Document examples in docs/features/policy.md"
  ],
  "blocked_by": [],
  "notes": [
    "Implemented with jq-based checks and helpful error messages; CI adds ajv-cli validation. See CHANGELOG and docs/features/policy.md."
  ],
  "created": "2025-09-25",
  "updated": "2025-10-06",
  "estimate": "med",
  "expected_complexity": "medium"
}

