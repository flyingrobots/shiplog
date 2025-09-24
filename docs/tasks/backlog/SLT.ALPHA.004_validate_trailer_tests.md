{
  "id": "SLT.ALPHA.004",
  "labels": ["tests"],
  "milestone": "Alpha",
  "name": "Validate-trailer tests",
  "description": "Add Bats tests covering malformed trailers and expected errors.",
  "priority": "P2",
  "impact": "prevents regressions in the new validation command",
  "steps": [
    "Craft commits with synthetic bad trailers in a sandbox repo",
    "Assert validate-trailer exits non-zero and prints expected errors"
  ],
  "blocked_by": [],
  "notes": [],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "small",
  "expected_complexity": "low"
}
