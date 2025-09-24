{
  "id": "SLT.ALPHA.011",
  "labels": ["ci", "docker"],
  "milestone": "Alpha",
  "name": "Clarify Ubuntu build args in matrix compose",
  "description": "Add inline comment explaining Ubuntu uses the Debian/apt family; adjust ci-matrix/docker-compose.yml accordingly.",
  "priority": "P3",
  "impact": "removes confusion in docker-compose.yml for Ubuntu service",
  "steps": [
    "Add clarifying comment for Ubuntu",
    "Verify build args still valid"
  ],
  "blocked_by": [],
  "notes": ["adjust ci-matrix/docker-compose.yml lines 16–64"],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "small",
  "expected_complexity": "low"
}

