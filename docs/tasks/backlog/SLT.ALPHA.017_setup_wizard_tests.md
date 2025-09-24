{
  "id": "SLT.ALPHA.017",
  "labels": ["tests", "cli", "setup"],
  "milestone": "Alpha",
  "name": "Tests for setup wizard and per-env policy",
  "description": "Docker-only Bats tests for setup modes (open/balanced/strict), per-env require_signed enforcement, policy show JSON fields/types, and policy toggle behavior.",
  "priority": "P1",
  "impact": "prevents regressions in user-guided flows",
  "steps": [
    "Test setup modes create expected policy/refs",
    "Pre-receive harness for per-env enforcement",
    "Validate policy show --json schema",
    "Test policy toggle syncs ref without push"
  ],
  "blocked_by": [],
  "notes": ["use sandbox harness and fake SSH keys"],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "med",
  "expected_complexity": "medium"
}

