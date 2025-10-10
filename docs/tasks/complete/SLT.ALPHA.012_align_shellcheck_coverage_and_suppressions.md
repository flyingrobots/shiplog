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
    "2025-10-09: Documented ShellCheck coverage/suppression policy in CONTRIBUTING and aligned the pre-commit helper with CI severity (-S error).",
    "CI lint job already runs shellcheck over bin/git-shiplog, contrib/hooks/**, and **/*.sh on PRs and pushes."
  ],
  "created": "2025-09-25",
  "updated": "2025-10-09",
  "estimate": "med",
  "expected_complexity": "low"
}
