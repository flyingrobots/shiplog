{
  "id": "SLT.ALPHA.012",
  "labels": ["lint", "shell"],
  "milestone": "Alpha",
  "name": "Align shellcheck coverage and suppressions",
  "description": "Run shellcheck across bin/ and scripts/ ensuring warnings addressed or documented; update Makefile/CI to run lint and capture expected suppressions; document lint requirements.",
  "priority": "P2",
  "impact": "keeps scripts maintainable and CI-friendly",
  "steps": [
    "Run shellcheck and triage warnings",
    "Add/justify suppressions where necessary",
    "Add CI job/Makefile target",
    "Document lint workflow in CONTRIBUTING"
  ],
  "blocked_by": [],
  "notes": ["depends on Bosun/installer refactors to settle"],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "med",
  "expected_complexity": "medium"
}

