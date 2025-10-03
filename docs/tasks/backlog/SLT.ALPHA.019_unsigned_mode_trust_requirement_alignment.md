{
  "id": "SLT.ALPHA.019",
  "labels": ["cli", "trust", "docs", "policy"],
  "milestone": "Alpha",
  "name": "Align unsigned mode with trust requirement",
  "description": "Decide and implement consistent behavior for unsigned mode: either allow missing trust when require_signed=false (and embed trust_oid=null), or explicitly document that trust is always required. Update CLI (cmd_write) and docs to match, and add tests.",
  "priority": "P1",
  "impact": "Removes onboarding friction and resolves doc/code mismatch for open/balanced mode.",
  "steps": [
    "Choose policy: allow-missing-trust when unsigned vs trust-always-required",
    "Implement cmd_write behavior (gate trust lookup on effective signing)",
    "Adjust trailer composer to handle trust_oid=null",
    "Update docs/features/modes.md and setup docs accordingly",
    "Add Bats tests for unsigned write with/without trust"
  ],
  "blocked_by": [],
  "notes": ["If keeping 'trust always required', simplify docs to state that explicitly"],
  "created": "2025-10-03",
  "updated": "2025-10-03",
  "estimate": "med",
  "expected_complexity": "medium"
}

