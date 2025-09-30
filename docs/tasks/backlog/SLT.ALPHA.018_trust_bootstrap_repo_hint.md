{
  "id": "SLT.ALPHA.018",
  "labels": ["cli", "trust"],
  "milestone": "Alpha",
  "name": "Improve trust bootstrap repo detection",
  "description": "Have trust bootstrap scripts fail early with a clear message when run outside a Git repo, including the resolved path.",
  "priority": "P3",
  "impact": "Reduces confusion when operators execute bootstrap tooling in the wrong working directory.",
  "steps": [
    "Detect git status before running bootstrap logic",
    "Emit actionable error with repo path if not inside a repo",
    "Add regression test to bootstrap helper"
  ],
  "blocked_by": [],
  "notes": [
    "DX feedback noted the script refusal was good but should hint at required repo context"
  ],
  "created": "2025-09-30",
  "updated": "2025-09-30",
  "estimate": "sm",
  "expected_complexity": "low"
}
