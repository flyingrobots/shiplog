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
  "notes": [
    "2025-10-10: Added test/24_validate_trailer.bats covering malformed JSON and missing field errors."
  ],
  "created": "2025-09-25",
  "updated": "2025-10-10",
  "estimate": "small",
  "expected_complexity": "low"
}
