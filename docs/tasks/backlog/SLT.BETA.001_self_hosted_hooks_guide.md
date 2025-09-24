{
  "id": "SLT.BETA.001",
  "labels": ["docs", "security"],
  "milestone": "Beta",
  "name": "Self-hosted hooks guide",
  "description": "Add docs/server/self-hosted.md with a pre-receive example and setup steps to enforce policy/trust on self-hosted Git.",
  "priority": "P2",
  "impact": "enables strict enforcement on self-hosted Git",
  "steps": [
    "Package a minimal pre-receive that checks allowlist and signatures",
    "Provide local bare-repo harness to test",
    "Document installation and rollback"
  ],
  "blocked_by": [],
  "notes": [],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "med",
  "expected_complexity": "medium"
}
