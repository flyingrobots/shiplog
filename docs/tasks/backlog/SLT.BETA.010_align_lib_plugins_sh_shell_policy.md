{
  "id": "SLT.BETA.010",
  "labels": ["shell", "plugins"],
  "milestone": "Beta",
  "name": "Align lib/plugins.sh with shell policy",
  "description": "Decide between POSIX-compatible implementation or explicit bash requirement; update shebang/directive/docs accordingly and adjust constructs (process substitution, arrays, sort -z).",
  "priority": "P1",
  "impact": "ensures plugin loader matches POSIX/guidelines",
  "steps": [
    "Choose POSIX vs bash requirement",
    "Update shebang and docs",
    "Refactor non-portable constructs",
    "Add regression tests"
  ],
  "blocked_by": [],
  "notes": ["address directives, process substitution, sorting portability"],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "med",
  "expected_complexity": "medium"
}

