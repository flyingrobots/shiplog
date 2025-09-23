# Runbook Topics (Brainstorm)

This section will grow into a collection of copy/pasteable runbooks for on-call engineers and SREs. Below is a brainstormed table of contents capturing the main areas we expect to document.

## Install & Bootstrap
- **Install Troubleshooting** – diagnosing failed `install-shiplog.sh` runs, missing dependencies, or incorrect `SHIPLOG_HOME`. Include “sanity check” commands (`git shiplog --help`, `git shiplog --version`).
- **First-Time Trust Setup** – how to use `scripts/shiplog-bootstrap-trust.sh`, what the generated files are, and how to push the genesis commit safely.
- **Policy Bootstrap** – enabling the initial `.shiplog/policy.json`, pushing to `refs/_shiplog/policy/current`, and syncing to clients.

## Daily Operations
- **Writing Entries** – checklist for CLI usage in dev/CI and the safety guardrails (containers, sandbox repos).
- **Syncing Signer Rosters** – using `shiplog-trust-sync` after a roster change, verifying `allowed_signers` distribution.
- **Monitoring/Verification** – typical checks (`git shiplog verify --env prod`, `git shiplog ls`) and what acceptable output looks like.

## Incident Response & Recovery
- **Journal Ref Fast-Forward Failures** – what happens if someone force-pushes or if refs diverge; steps to reconcile.
- **Trust/Policy Drift** – detecting stale trust OIDs, missing signatures, or mismatched policy refs.
- **Sandbox & Test Harness Issues** – diagnosing test failures in `make test` or the CI matrix; pointer to Docker docs.

## Upgrades & Maintenance
- **Upgrading Dependencies** – how to bump Git/jq versions in Dockerfiles, rebuild images, and run the pre-push container builds.
- **Updating Bosun/CLI** – version bumps, `--version` flag behavior, distribution considerations.
- **CI Matrix Maintenance** – adding/removing distros, tweaking base images, and verifying matrix runs locally.

## Common Problems & Solutions
- **Install Script Cannot Resolve Paths** (from the path safety work).
- **`git shiplog` refuses to run** – missing dependencies, trust violations, or running in the repo on the host.
- **Devcontainer Fails to Build** – symptoms, likely cause (missing files, network), remediation steps.
- **`shiplog-trust-sync` Fails** – network issues, missing refs, GPG misconfiguration.

## Future Topics / Ideas
- Integrating Shiplog with CI/CD (sample pipelines).
- Exporting logs to monitoring systems (using `git shiplog export-json`).
- How to enforce runbooks via hooks to keep incidents consistent.

_This page is intentionally a brainstorm; as we produce actual runbooks, each bullet will receive its own file under `docs/runbooks/`._
