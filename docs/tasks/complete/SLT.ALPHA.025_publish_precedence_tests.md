{
  "id": "SLT.ALPHA.025",
  "labels": ["tests", "publish"],
  "milestone": "Alpha",
  "name": "Publish/auto-push precedence tests",
  "description": "Validate that explicit publish works regardless of auto-push settings; test runs in CI.",
  "priority": "P3",
  "impact": "Clarifies separation between write and publish",
  "steps": [
    "Write entry without pushing",
    "Publish env journal and verify success"
  ],
  "blocked_by": [],
  "notes": [
    "Implemented in test/19_publish_and_autopush_precedence.bats; uses bare remote harness and grep assertion."
  ],
  "created": "2025-10-05",
  "updated": "2025-10-06",
  "estimate": "small",
  "expected_complexity": "low"
}

