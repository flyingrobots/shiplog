{
  "id": "SLT.BETA.018",
  "labels": ["anchors", "cli", "hooks"],
  "milestone": "Beta",
  "name": "Anchors lifecycle: commands and flow",
  "description": "Design and implement anchor operations for refs/_shiplog/anchors/<env>. Provide a command to create/move an anchor, update trailer semantics, and (optionally) enforce linearity between anchors.",
  "priority": "P3",
  "impact": "Enables useful \"since last anchor\" reporting and navigation across long journals.",
  "steps": [
    "Define anchor semantics and UX",
    "Implement git shiplog anchor [create|move|show]",
    "Wire anchors into write/run flows as appropriate",
    "Add docs and examples"
  ],
  "blocked_by": [],
  "notes": ["Keep anchor operations fast-forward only"],
  "created": "2025-10-03",
  "updated": "2025-10-03",
  "estimate": "med",
  "expected_complexity": "medium"
}

