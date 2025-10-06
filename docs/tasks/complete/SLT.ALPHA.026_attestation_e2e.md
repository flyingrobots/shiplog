{
  "id": "SLT.ALPHA.026",
  "labels": ["tests", "attestation"],
  "milestone": "Alpha",
  "name": "Attestation E2E tests",
  "description": "End-to-end tests for attestation verification (ssh-keygen -Y verify) with ephemeral keys and threshold signatures across matrix distros.",
  "priority": "P3",
  "impact": "Ensures attestation path remains portable and secure",
  "steps": [
    "Generate test keys and allowed_signers",
    "Sign canonical payload and verify threshold",
    "Skip only when ssh-keygen -Y is unavailable"
  ],
  "blocked_by": [],
  "notes": [
    "Implemented in test/22_attestation_e2e.bats; uses BASE payload mode (default) and conditional skip when ssh-keygen lacks -Y.",
    "Matrix images include openssh-keygen for Alpine and appropriate clients for Debian/Ubuntu/Fedora/Arch."
  ],
  "created": "2025-10-05",
  "updated": "2025-10-06",
  "estimate": "med",
  "expected_complexity": "medium"
}

