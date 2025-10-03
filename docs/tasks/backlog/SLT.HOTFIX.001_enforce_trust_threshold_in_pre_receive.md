{
  "id": "SLT.HOTFIX.001",
  "labels": ["hooks", "trust", "security"],
  "milestone": "HOTFIX",
  "name": "Enforce trust threshold in pre-receive hook",
  "description": "Update contrib/hooks/pre-receive.shiplog to verify that updates to refs/_shiplog/trust/root are co-signed by at least the configured threshold of maintainers in trust.json. Reject pushes that do not meet the N-of-M requirement.",
  "priority": "P0",
  "impact": "Prevents unauthorized or under-signed trust changes; closes a critical integrity gap for production deployments.",
  "steps": [
    "Parse trust.json (threshold, maintainers) from new trust tip",
    "Collect valid signatures on the new trust commit (SSH or OpenPGP)",
    "Map signatures to maintainer principals/keys; count distinct maintainers",
    "Reject if count < threshold; include friendly error with details",
    "Add Dockerized Bats tests for passing/failing updates",
    "Document behavior in docs/TRUST.md and contrib/README.md"
  ],
  "blocked_by": [],
  "notes": [
    "For SSH signatures, use GIT_SSH_ALLOWED_SIGNERS with the allowed_signers blob to validate each signature",
    "For PGP, verify via git verify-commit and parse signers; prefer SSH in CI"
  ],
  "created": "2025-10-03",
  "updated": "2025-10-03",
  "estimate": "med",
  "expected_complexity": "high"
}

