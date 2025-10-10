{
  "id": "SLT.ALPHA.002",
  "labels": ["docs"],
  "milestone": "Alpha",
  "name": "Document tooling versions in README",
  "description": "Add minimum supported versions for git, jq, bash; note ssh-keygen requirement in CI/matrix.",
  "priority": "P3",
  "impact": "sets clear expectations for environments",
  "steps": [
    "Add a small \"Requirements\" block in README",
    "Align versions with CI matrix images"
  ],
  "blocked_by": [],
  "notes": [
    "2025-10-10: Added Requirements block covering git/bash/jq/ssh-keygen to README and shiplog_readme."
  ],
  "created": "2025-09-25",
  "updated": "2025-10-10",
  "estimate": "small",
  "expected_complexity": "low"
}
