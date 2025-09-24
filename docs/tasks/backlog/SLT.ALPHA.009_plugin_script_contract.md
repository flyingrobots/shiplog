{
  "id": "SLT.ALPHA.009",
  "labels": ["docs", "plugins"],
  "milestone": "Alpha",
  "name": "Clarify plugin script contract",
  "description": "Specify stderr handling, timeouts, env vars, working dir, stdin format, and input limits. Replace unsafe regex example with vetted patterns; add tests covering error paths.",
  "priority": "P1",
  "impact": "ensures plugin authors know stderr/timeout/env semantics",
  "steps": [
    "Define execution environment and cwd",
    "Document stdin format and size limits",
    "Describe stderr capture and timeouts",
    "Replace unsafe regex example with vetted patterns",
    "Add tests for error and timeout paths"
  ],
  "blocked_by": [],
  "notes": ["update docs/plugins.md script interface (~19–32)"],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "med",
  "expected_complexity": "medium"
}

