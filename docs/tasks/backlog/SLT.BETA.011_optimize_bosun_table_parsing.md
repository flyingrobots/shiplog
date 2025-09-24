{
  "id": "SLT.BETA.011",
  "labels": ["bosun", "perf"],
  "milestone": "Beta",
  "name": "Optimize Bosun table parsing",
  "description": "Replace split_string loops with localized IFS/read usage for widths and printing to improve speed and portability.",
  "priority": "P1",
  "impact": "faster, portable table rendering",
  "steps": [
    "Profile current parser",
    "Refactor to localized IFS/read",
    "Validate rendering under Docker matrix",
    "Add regression tests"
  ],
  "blocked_by": [],
  "notes": ["refactor sections around rows parsing in scripts/bosun"],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "med",
  "expected_complexity": "medium"
}

