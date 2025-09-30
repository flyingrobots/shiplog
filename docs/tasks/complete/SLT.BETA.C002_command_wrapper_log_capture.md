{
  "id": "SLT.BETA.C002",
  "labels": ["cli"],
  "milestone": "Beta",
  "name": "Command wrapper with log capture",
  "description": "Add `git shiplog run <cmd>` to wrap commands, tee output to a temp file, attach logs as notes, and emit structured run metadata.",
  "priority": "P1",
  "impact": "makes it trivial to wrap deployments/tests and attach structured logs",
  "steps": [],
  "blocked_by": [],
  "notes": [
    "Implemented in v0.2.0: git shiplog run with structured `run` trailer and log attachment."
  ],
  "created": "2025-09-25",
  "updated": "2025-09-30",
  "estimate": "med",
  "expected_complexity": "medium"
}
