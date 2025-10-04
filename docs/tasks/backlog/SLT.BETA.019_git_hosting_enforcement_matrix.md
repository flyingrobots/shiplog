{
  "id": "SLT.BETA.019",
  "labels": ["docs", "hosting", "github", "gitlab", "gitea", "bitbucket"],
  "milestone": "Beta",
  "name": "Git hosting enforcement matrix and guidance",
  "description": "Publish a docs/hosting/matrix.md covering enforcement capabilities and recommended setups for GitHub.com, GitHub Enterprise, GitLab (SaaS/self-managed), Gitea, and Bitbucket (Cloud/Data Center). Include branch/custom refs tradeoffs, rulesets/protected branches, required status checks, and where server hooks are available.",
  "priority": "P2",
  "impact": "Sets clear expectations for teams using SaaS vs self-hosted platforms; reduces misconfiguration and false assumptions about server-side enforcement.",
  "steps": [
    "Add docs/hosting/matrix.md with per-host tables and examples",
    "Link GitHub branch namespace strategy + rulesets + required checks",
    "Document GitLab protected branches and pipelines; hooks for self-managed",
    "Document Gitea/GitHub Enterprise hooks; Bitbucket Cloud limitations",
    "Cross-link from docs/hosting/github.md and runbooks"
  ],
  "blocked_by": [],
  "notes": ["Consider adding example workflows for host-specific required checks"],
  "created": "2025-10-03",
  "updated": "2025-10-03",
  "estimate": "med",
  "expected_complexity": "medium"
}

