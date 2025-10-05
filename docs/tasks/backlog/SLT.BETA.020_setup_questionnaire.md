{
  "id": "SLT.BETA.020",
  "labels": ["cli", "setup", "ux", "docs"],
  "milestone": "Beta",
  "name": "Setup Questionnaire (guided configuration)",
  "description": "Add an interactive setup questionnaire that asks targeted questions (hosting, enforcement, PR workflow, threshold, key types, deployment cadence) and produces a tailored Shiplog configuration: signing mode (chain/attestation), threshold, trust bootstrap choices, ref namespace (custom vs branch), auto-push policy, and CI/Ruleset recommendations. Provide a non-interactive mode that accepts pre-answered choices.",
  "priority": "P1",
  "impact": "Reduces onboarding friction; yields sane, host-aware defaults and fewer misconfigurations.",
  "steps": [
    "Design question set and mapping to outputs (sig_mode, threshold, ref root, autoPush, workflows)",
    "Implement CLI: git shiplog config --interactive (TTY UI via Bosun + plain fallback)",
    "Emit: .shiplog/policy.json, trust bootstrap flags, suggested CI workflow and ruleset snippets",
    "Add non-interactive mode: accept answers via JSON/flags and print a plan",
    "Docs: how it works + examples; link from README and TRUST docs",
    "Tests: Dockerized bats covering key decision branches"
  ],
  "blocked_by": ["SLT.BETA.019"],
  "notes": [
    "Answers include: host (GitHub.com/GitLab/Gitea/self-hosted), PR style (squash vs multi-commit), enforcement preference, threshold typical, key types, deploy cadence, pushing during deploys",
    "Outputs include: sig_mode, recommended required checks, ruleset/protection guidance, auto-push default, publish advice"
  ],
  "created": "2025-10-03",
  "updated": "2025-10-03",
  "estimate": "big",
  "expected_complexity": "high"
}
