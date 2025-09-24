{
  "id": "SLT.ALPHA.020",
  "labels": ["portability", "time"],
  "milestone": "Alpha",
  "name": "macOS time helpers portability",
  "description": "Audit GNU date usage; implement portable alternatives via POSIX date or Python fallback; add helper and tests.",
  "priority": "P2",
  "impact": "ensures time/duration operations work on macOS and Linux",
  "steps": [
    "Remove GNU date -d usage",
    "Compute durations via epoch capture",
    "Add helper and tests"
  ],
  "blocked_by": [],
  "notes": ["DONE: removed GNU date -d; portable"],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "small",
  "expected_complexity": "low"
}

