# Changelog

## [0.4.0-alpha] – 2025-10-06
Highlights:
- Trust verification hardening and robust cross‑distro behavior.
- New gate modes for signed trust updates: `commit|attestation|either`.
- Verbose verifier diagnostics to speed up debugging in CI and on servers.
- End‑to‑end attestation test using real `ssh-keygen -Y` signatures.

Changes:
- feat(verify): Add `SHIPLOG_DEBUG_SSH_VERIFY` instrumentation (shared verifier + pre‑receive hook).
- feat(verify): Support `SHIPLOG_REQUIRE_SIGNED_TRUST_MODE=commit|attestation|either`.
- test: Unskip and stabilize “signed trust push passes” (principal probe + either‑mode fallback).
- test: Add attestation E2E (`threshold=2`) with ephemeral keys and detached signatures.
- docs: Document gate modes and troubleshooting in `docs/TRUST.md` and `docs/reference/env.md`.

Notes:
- The attestation verifier uses a canonical payload over the trust tree (base mode by default). A back‑compat toggle allows verifying older signatures over the full tree.

## [0.3.0] – 2025-10-05
Highlights:
- Config Wizard (`git shiplog config`) with `--interactive`, `--apply`, and answers file.
- Policy validation in CLI and schema check in CI.
- README/docs sweeps and Git hosts guidance.

Changes:
- feat(config): Add guided, host‑aware onboarding; dry‑run JSON plan.
- feat(policy): `git shiplog policy validate` with structural checks.
- ci: Add non‑blocking AJV schema job; tighten yamllint; maintainers/owner guardrails.
- docs: Trust modes diagram (SVG), hosting matrix, publish/auto‑push precedence, FAQ.

## [0.2.0] – 2025-09-30
**Codename:** The Cut of Your Jib

- Added `git shiplog run` to wrap commands, capture logs, and record structured run metadata.
- Added `git shiplog append` for non-interactive entries via `--json` / `--json-file` (stdin supported).
- Added `git shiplog trust show` (table and `--json`) including signer inventory.
- Documented the structured entry schema (`docs/reference/json-schema.md`).
- Defaulted the namespace to the journal name when `SHIPLOG_NAMESPACE` is unset.

## [0.1.0] – 2025-09-26
- Initial tagged release.
