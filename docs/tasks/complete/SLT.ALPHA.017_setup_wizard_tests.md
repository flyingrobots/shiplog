{
  "id": "SLT.ALPHA.017",
  "labels": ["tests", "wizard", "policy"],
  "milestone": "Alpha",
  "name": "Tests for setup wizard and per-env policy",
  "description": "Docker-only Bats tests for setup modes (open/balanced/strict), policy outputs, and apply/dry-run behavior.",
  "priority": "P1",
  "impact": "Strengthens onboarding and policy coverage",
  "steps": [
    "Add Bats tests for config wizard (--interactive, --apply)",
    "Validate policy outputs and defaults"
  ],
  "blocked_by": [],
  "notes": [
    "Implemented in test/20_config_wizard.bats; see also docs/tasks/complete/SLT.ALPHA.C023_config_wizard_bats_tests.md."
  ],
  "created": "2025-09-25",
  "updated": "2025-10-06",
  "estimate": "med",
  "expected_complexity": "medium"
}

