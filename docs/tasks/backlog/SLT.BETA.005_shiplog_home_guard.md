{
  "id": "SLT.BETA.005",
  "labels": ["safety"],
  "milestone": "Beta",
  "name": "SHIPLOG_HOME guard",
  "description": "Warn when write/setup commands run inside $SHIPLOG_HOME to prevent accidental mutations in installer repo.",
  "priority": "P3",
  "impact": "prevents accidental writes in installer repo",
  "steps": [
    "Detect PWD under $SHIPLOG_HOME",
    "Print warning to stderr; allow override via env"
  ],
  "blocked_by": [],
  "notes": [],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "small",
  "expected_complexity": "low"
}
