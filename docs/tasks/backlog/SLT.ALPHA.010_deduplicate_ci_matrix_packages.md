{
  "id": "SLT.ALPHA.010",
  "labels": ["ci", "docker"],
  "milestone": "Alpha",
  "name": "Deduplicate CI matrix package installs",
  "description": "Introduce shared package list in ci-matrix/Dockerfile with distro-specific additions; document package purpose and retain cleanup commands per distro.",
  "priority": "P1",
  "impact": "keeps distro builds consistent and maintainable",
  "steps": [
    "Extract common package list",
    "Parameterize distro-specific additions",
    "Add comments explaining purpose",
    "Retain cleanup and cache trimming"
  ],
  "blocked_by": [],
  "notes": ["clean up lines 12–27 in ci-matrix/Dockerfile"],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "med",
  "expected_complexity": "medium"
}

