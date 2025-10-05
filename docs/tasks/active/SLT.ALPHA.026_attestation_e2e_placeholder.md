{
  "id": "SLT.ALPHA.026",
  "labels": ["tests", "attestation"],
  "milestone": "Alpha",
  "name": "Attestation E2E tests (placeholder)",
  "description": "Add end-to-end tests for attestation verification (ssh-keygen -Y verify) with signed fixtures across distros.",
  "priority": "P3",
  "impact": "Ensures attestation path remains portable and secure",
  "steps": [
    "Generate test keys and signed payload fixtures",
    "Commit fixtures and verify threshold >= N",
    "Unskip in CI after fixtures are in place"
  ],
  "blocked_by": [],
  "notes": ["Currently skipped: test/22_attestation_e2e.bats"],
  "created": "2025-10-05",
  "updated": "2025-10-05",
  "estimate": "med",
  "expected_complexity": "medium"
}

