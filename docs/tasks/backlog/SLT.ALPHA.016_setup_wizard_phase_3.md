{
  "id": "SLT.ALPHA.016",
  "labels": ["cli", "setup"],
  "milestone": "Alpha",
  "name": "Setup wizard refinements (Phase 3)",
  "description": "Add per-environment strictness (e.g., prod only), offer auto-push, add non-interactive flags for all setup inputs (authors, envs) and print exact commands, detect and suggest relaxed hook envs if trust/policy missing on server, and add rollback safety (backup + diff).",
  "priority": "P1",
  "impact": "simplifies initial configuration and reduces lock-in/friction",
  "steps": [
    "Per-env strictness option (e.g., prod only)",
    "Offer to auto-push policy/trust refs",
    "Add non-interactive flags for all setup inputs (authors, envs) and print exact commands",
    "Detect and suggest relaxed hook envs if trust/policy missing on server",
    "Add rollback safety: backup existing .shiplog/policy.json before overwrite and show diff"
  ],
  "blocked_by": [],
  "notes": [
    "integrate with shiplog-bootstrap-trust.sh env mode",
    "support multiple maintainers"
  ],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "big",
  "expected_complexity": "high"
}
