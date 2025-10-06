{
  "id": "SLT.ALPHA.025",
  "labels": ["tests", "publish"],
  "milestone": "Alpha",
  "name": "Publish/auto-push precedence tests",
  "description": "Validate that explicit publish works regardless of auto-push settings; keep test skipped until harness is stable.",
  "priority": "P3",
  "impact": "Clarifies separation between write and publish",
  "steps": [
    "Write entry without pushing",
    "Publish env journal and verify success",
    "Unskip when push harness stabilized"
  ],
  "blocked_by": [],
  "notes": ["Placeholder implemented in test/19_publish_and_autopush_precedence.bats (skip)"],
  "created": "2025-10-05",
  "updated": "2025-10-05",
  "estimate": "small",
  "expected_complexity": "low"
}

