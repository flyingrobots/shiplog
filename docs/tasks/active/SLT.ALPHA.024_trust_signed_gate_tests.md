{
  "id": "SLT.ALPHA.024",
  "labels": ["tests", "trust", "hooks"],
  "milestone": "Alpha",
  "name": "Add E2E tests for trust-signed gate",
  "description": "When SHIPLOG_REQUIRE_SIGNED_TRUST=1 in the remote hook environment, unsigned trust pushes are rejected; signed pushes pass.",
  "priority": "P2",
  "impact": "Prevents regressions in server-side enforcement",
  "steps": [
    "Install hook in a bare repo and set env gate",
    "Push unsigned trust: expect rejection",
    "Create and push signed trust commit: expect success"
  ],
  "blocked_by": [],
  "notes": ["Implemented in test/18_trust_signed_gate.bats"],
  "created": "2025-10-05",
  "updated": "2025-10-05",
  "estimate": "small",
  "expected_complexity": "low"
}

