{
  "id": "SLT.BETA.003",
  "labels": ["cli"],
  "milestone": "Beta",
  "name": "Trust show subcommand",
  "description": "Add `git shiplog trust show` printing trust id, threshold, and maintainer roster (revoked flags) in table/JSON.",
  "priority": "P3",
  "impact": "quick insight into trust state",
  "steps": [
    "Read trust.json from trust ref and render fields",
    "Support --json output"
  ],
  "blocked_by": [],
  "notes": [],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "small",
  "expected_complexity": "low"
}
