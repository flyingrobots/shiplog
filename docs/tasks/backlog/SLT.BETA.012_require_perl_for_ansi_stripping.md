{
  "id": "SLT.BETA.012",
  "labels": ["bosun", "deps"],
  "milestone": "Beta",
  "name": "Require perl for ANSI stripping",
  "description": "Fail fast with a clear error if perl is unavailable and update docs to reflect dependency; adjust strip_ansi fallback branch in scripts/bosun.",
  "priority": "P2",
  "impact": "predictable Bosun output when perl is missing",
  "steps": [
    "Detect perl availability",
    "Emit clear failure with guidance",
    "Update docs with dependency note"
  ],
  "blocked_by": [],
  "notes": [],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "small",
  "expected_complexity": "low"
}

