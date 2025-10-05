Contributing to Shiplog

Thank you for your interest in contributing! We welcome issues, docs fixes, and PRs.

- Open issues with clear steps to reproduce or a concise proposal.
- For PRs, keep changes focused and include tests when touching behavior.
- Run locally: `make test` (Dockerized) and `gh pr create` to open PRs.
- Do not run Bats tests directly on your host. Always use `make test`.
- Keep progress bars current: run `make progress` if you update tasks under `docs/tasks/`.

Code of Conduct: see CODE_OF_CONDUCT.md.
Security reports: see SECURITY.md.

Merging policy
- Do not merge PRs without explicit owner approval.
- All PRs must have the label `approved-by-owner` and a passing check from the `require-owner-approval` workflow.
- CODEOWNERS requires a review from @flyingrobots on all paths.
