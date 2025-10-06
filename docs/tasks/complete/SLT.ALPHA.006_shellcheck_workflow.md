{
  "id": "SLT.ALPHA.006",
  "labels": ["ci", "lint"],
  "milestone": "Alpha",
  "name": "Shellcheck workflow",
  "description": "Add a GitHub Actions job to run shellcheck across bin/, scripts/, lib/ (include contrib/hooks/**).",
  "priority": "P2",
  "impact": "keeps scripts maintainable and CI-friendly",
  "steps": [
    "Add shellcheck job to CI",
    "Document acceptable suppressions"
  ],
  "blocked_by": [],
  "notes": [
    "Implemented in .github/workflows/lint.yml; covers bin/git-shiplog, contrib/hooks/**, and **/*.sh; runs on PRs (changed-only) and pushes (full repo)."
  ],
  "created": "2025-09-25",
  "updated": "2025-10-06",
  "estimate": "med",
  "expected_complexity": "low"
}

