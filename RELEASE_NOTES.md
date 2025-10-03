# Shiplog — Next Release (Unreleased)

This note summarizes what’s changing, what you need to do (by scenario), SaaS vs self‑hosted enforcement guidance, and UX improvements requested by early adopters.

## Highlights

- Trust quorum modes (sig_mode): choose between `chain` (co‑sign commits) or `attestation` (detached signature files) to meet `threshold` maintainer signatures.
- Unified trust verifier: a single script validates trust updates for hooks and CI.
- SaaS‑friendly enforcement: example GitHub workflow added to make trust checks a Required Status Check on `_shiplog/**`.
- Cleaner CLI output: `git shiplog run` now streams the wrapped command output and prints a short success line instead of a full entry preview.
- Friendlier headers/tables: optional fields are hidden in human headers; `ls` avoids noisy `?` placeholders.

## What’s New

### 1) Trust Signing Modes

- New field in `.shiplog/trust.json`:
  - `"sig_mode": "chain" | "attestation"`
- `chain` (co‑sign chain): each maintainer signs the same trust tree by adding a commit over that tree; threshold is met when ≥ `threshold` distinct maintainer‑signed commits are present in a fast‑forward update.
- `attestation` (detached sigs): keep one trust commit; store ≥ `threshold` signature files under `.shiplog/trust_sigs/` that sign the trust tree OID.

Choosing the mode:

```bash
# Interactive bootstrap will prompt; defaults to chain
./scripts/shiplog-bootstrap-trust.sh --trust-sig-mode chain   # or attestation

# Non-interactive
SHIPLOG_TRUST_SIG_MODE=attestation git shiplog setup
```

### 2) Verification (Hooks and SaaS)

- New: `scripts/shiplog-verify-trust.sh` — shared verifier used by both server hooks and CI.
- Pre‑receive hook now calls the verifier when present (self‑hosted). Fallback still requires a valid signature and blocks `threshold>1` without an env escape hatch.
- SaaS (GitHub.com et al.): example workflow at `docs/examples/github/workflow-shiplog-trust-verify.yml` you can mark as a Required Status Check for `_shiplog/**`.

### 3) Cleaner Output

- `git shiplog run` no longer prints the full entry preview. It streams the wrapped command, then prints a one‑liner like `Recorded to Shiplog [abcd123]`.
- Human headers now hide missing location parts. If you only have `env=prod`, headers render `→ prod` (no `?/?/?`).
- `git shiplog ls` reads env/service/status from JSON (when jq is available) and prints `-` for missing values instead of `?`.

## What You Need To Do

> TL;DR: update scripts and hooks; pick a mode only if you’ll use `threshold>1`; add a Required Check on SaaS.

### Self‑Hosted (GitHub Enterprise, GitLab self‑managed, Gitea, Bitbucket DC)

1) Update the server’s hook and scripts:
   - Install `contrib/hooks/pre-receive.shiplog` (replace the previous version).
   - Ensure `scripts/shiplog-verify-trust.sh` is in the repo alongside the hook.
2) If `threshold==1` today, you’re done. If `threshold>1` or will be:
   - Choose a `sig_mode` (`chain` or `attestation`) and create the next trust update accordingly.
3) Optional: re‑run `./scripts/shiplog-trust-sync.sh` on workstations/CI to refresh `gpg.ssh.allowedSignersFile`.

### SaaS (GitHub.com, GitLab SaaS, Bitbucket Cloud)

1) Use branch namespace for Shiplog refs (`refs/heads/_shiplog/**`) and protect it (no deletions, no force‑push, require PRs).
2) Add the “Shiplog Trust Verify” workflow as a Required Status Check on `_shiplog/**`.
3) If `threshold>1`, pick a `sig_mode` and follow the pattern for co‑signing or attaching signatures in PRs.

## Compatibility

- If `sig_mode` is missing in `trust.json`, verification defaults to `chain` and still requires the trust commit to be signature‑verified.
- No journal/history rewrites are needed. Existing entries remain valid.

## Migration Notes (Threshold > 1)

- Chain mode (recommended for self‑hosted): PR with ≥ `threshold` signer commits over the same trust tree; merge fast‑forward.
- Attestation mode (recommended for SaaS): PR adds ≥ `threshold` `.sig` files under `.shiplog/trust_sigs/` that sign the trust tree OID; squash to a single trust commit; Required Check verifies them.
- Temporary escape hatch for staged rollouts (self‑hosted only): set `SHIPLOG_ALLOW_TRUST_THRESHOLD_UNENFORCED=1` for the Git server user; remove ASAP.

## UX Changes in CLI

- `shiplog run` now prints a concise confirmation line. It still returns the wrapped command’s exit code and attaches logs as notes when non‑empty.
- Human headers hide absent fields; no more `?` placeholders. Tables prefer `-` when a value is missing.

## Known Follow‑ups

- Attestation signature verification: a small helper will be added to emit and verify SSH signatures over a canonical payload (tree OID + context). The verifier will then enforce validity (not just presence) for `.sig` files.
- Hosting matrix doc: guidance for GitHub/GitLab/Bitbucket/Gitea with prescriptive protection settings and Required Checks.

