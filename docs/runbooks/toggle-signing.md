# Toggle Signing (Unsigned ↔ Signed)

Use this runbook to switch your repository between unsigned and signed modes. No history rewrites are needed; changes apply to new pushes only.

## Unsigned → Signed

1) Bootstrap trust (once)
- Interactive: `./scripts/shiplog-bootstrap-trust.sh`
- Or env-driven (see docs/features/modes.md:1 for variables)
- Push: `git push origin refs/_shiplog/trust/root`

2) Distribute signers
- `./scripts/shiplog-trust-sync.sh`

3) Require signatures in policy and publish
```
# One-liner helper
git shiplog policy require-signed true
git push origin refs/_shiplog/policy/current
```

4) Ensure clients/CI can sign
- Configure SSH signing: `git config --global gpg.format ssh && git config --global user.signingkey ~/.ssh/id_ed25519`
- Optionally set `SHIPLOG_SIGN=1` in jobs (policy will require it regardless).

## Signed → Unsigned

1) Flip policy off and publish
```
# One-liner helper
git shiplog policy require-signed false
git push origin refs/_shiplog/policy/current
```

2) Clients can stop signing
- Remove any `SHIPLOG_SIGN=1` overrides.

## Server: Relaxed Bootstrap (optional)

If you want to push entries before trust/policy exist on the server, set these envs for the hook user (temporarily):

- `SHIPLOG_ALLOW_MISSING_POLICY=1`
- `SHIPLOG_ALLOW_MISSING_TRUST=1`

Note: If `require_signed=true`, trust must be present to verify signatures.

## Verify

- Push a test entry to a non-prod journal to confirm the hook behavior matches your policy.
- Inspect policy effective state with `git shiplog policy` (planned) or by reading `.shiplog/policy.json` and the policy ref.
