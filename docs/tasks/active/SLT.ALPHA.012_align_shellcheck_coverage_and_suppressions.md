{
  "id": "SLT.ALPHA.012",
  "labels": ["ci", "lint"],
  "milestone": "Alpha",
  "name": "Align shellcheck coverage and suppressions",
  "description": "Ensure CI covers all shell files (including contrib/hooks/**) with consistent severity and documented suppressions; update docs to reflect policy.",
  "priority": "P2",
  "impact": "keeps script quality high and CI predictable",
  "steps": [
    "Audit coverage and confirm nested hooks included",
    "Document suppressions and severity policy in CONTRIBUTING",
    "Tighten rules incrementally where safe"
  ],
  "blocked_by": [],
  "notes": [
    "Partially implemented: workflow exists and runs at -S error; this task tracks documentation and final coverage audit."
  ],
  "created": "2025-09-25",
  "updated": "2025-10-06",
  "estimate": "med",
  "expected_complexity": "low"
}

