{
  "id": "SLT.BETA.009",
  "labels": ["cli"],
  "milestone": "Beta",
  "name": "Command wrapper with log capture",
  "description": "Add `git shiplog run <cmd>` (or similar) to tee output to a temp file and attach logs as notes.",
  "priority": "P1",
  "impact": "makes it trivial to wrap deployments/tests and attach structured logs",
  "steps": [
    "Implement run wrapper",
    "Support JSON/timestamp formatting and filters",
    "Docs and examples"
  ],
  "blocked_by": [],
  "notes": [],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "med",
  "expected_complexity": "medium"
}
