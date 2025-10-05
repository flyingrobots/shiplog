{
  "id": "SLT.BETA.021",
  "labels": ["cli", "config", "ci", "docs", "hosting"],
  "milestone": "Beta",
  "name": "Config wizard: emit CI workflows and rulesets",
  "description": "Extend `git shiplog config` with flags (e.g., `--emit-ci github|gitlab|bitbucket` and `--emit-ruleset`) that write recommended CI workflow files and Ruleset JSON for the chosen host/namespace. Support dry-run previews and safe overwrite behavior.",
  "priority": "P2",
  "impact": "Shortens setup time and reduces misconfiguration for SaaS vs self-hosted deployments.",
  "steps": [
    "Design flag interface and output locations",
    "Implement emit logic with dry-run preview and overwrite prompt",
    "Templates: GitHub Actions (trust verify + journal/policy verify)",
    "Templates: GitLab CI and Bitbucket pipelines equivalents",
    "Ruleset JSON for branch namespace (_shiplog/**)",
    "Docs: update features/config.md and hosting guides",
    "Tests: minimal Bats to assert file creation and contents markers"
  ],
  "blocked_by": ["SLT.ALPHA.023"],
  "notes": ["Consider `--emit-ci auto` to infer from host"],
  "created": "2025-10-05",
  "updated": "2025-10-05",
  "estimate": "big",
  "expected_complexity": "high"
}

