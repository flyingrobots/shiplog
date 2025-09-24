# Security Modes and Signing

Shiplog supports two modes of operation:

- Unsigned mode (default): Entries are not required to be signed. Useful for fast adoption and local trials.
- Signed mode: Entries must be signed and verified against a trusted signer roster. Enables strong provenance.

Policy controls which mode is active. You can switch at any time without rewriting history.

## Current Mode and Defaults

- Default mode: unsigned. The CLI does not sign by default unless the policy requires it or you set `SHIPLOG_SIGN=1`.
- To view effective policy: `git shiplog policy` (planned) or inspect `.shiplog/policy.json` and the policy ref (`refs/_shiplog/policy/current`).

## Enabling Signing

1) Bootstrap trust (once)
- Create a signed trust commit at `refs/_shiplog/trust/root` containing `trust.json` and `allowed_signers`.
- Interactive: `./scripts/shiplog-bootstrap-trust.sh`
- Non-interactive (env-driven):

```
export SHIPLOG_TRUST_COUNT=1
export SHIPLOG_TRUST_ID="shiplog-trust-root"
export SHIPLOG_TRUST_1_NAME="Your Name"
export SHIPLOG_TRUST_1_EMAIL="you@example.com"
export SHIPLOG_TRUST_1_ROLE="root"
export SHIPLOG_TRUST_1_PGP_FPR=""
export SHIPLOG_TRUST_1_SSH_KEY_PATH="$HOME/.ssh/id_ed25519.pub"
export SHIPLOG_TRUST_1_PRINCIPAL="you@example.com"
export SHIPLOG_TRUST_1_REVOKED="no"
export SHIPLOG_TRUST_THRESHOLD=1
export SHIPLOG_TRUST_COMMIT_MESSAGE="shiplog: trust root v1 (GENESIS)"
export SHIPLOG_ASSUME_YES=1 SHIPLOG_PLAIN=1
./scripts/shiplog-bootstrap-trust.sh
```

2) Distribute allowed signers
- Install the signer roster on each machine and point Git at it:

```
./scripts/shiplog-trust-sync.sh
```

3) Require signatures in policy
- Edit `.shiplog/policy.json` and set:

```
{"version": 1, "require_signed": true, ...}
```

- Publish the policy ref and push:

```
./scripts/shiplog-sync-policy.sh
git push origin refs/_shiplog/policy/current
```

4) Configure clients/CI to sign
- Either rely on policy, or explicitly set `SHIPLOG_SIGN=1` on jobs.
- Configure the signing key (`git config gpg.format ssh` + `user.signingkey` for SSH).

## Disabling Signing

1) Flip policy off and publish

```
# Edit .shiplog/policy.json
{"version": 1, "require_signed": false, ...}

./scripts/shiplog-sync-policy.sh
git push origin refs/_shiplog/policy/current
```

2) Clients stop signing automatically
- CLI default is unsigned; remove `SHIPLOG_SIGN=1` if you were setting it.
- You can keep the trust ref; it is simply not used when `require_signed` is false.

## Server Enforcement and Bootstrap

By default, the pre-receive hook requires trust and policy and enforces signatures when policy requires it. During bootstrap, you may allow missing refs:

- `SHIPLOG_ALLOW_MISSING_POLICY=1` — accept journal pushes without a policy ref; treats policy as `require_signed=false` and empty author allowlist.
- `SHIPLOG_ALLOW_MISSING_TRUST=1` — accept journal pushes when the trust ref is missing; skips `trust_oid` equality checks. If `require_signed=true`, trust is still required to verify signatures.

Set these as environment variables for the Git server user running the hook. See `contrib/README.md` for details.

## FAQ

- Do I need to rewrite existing entries when switching? No. Enforcement applies to new pushes.
- Can I sign some environments but not others? Today `require_signed` is global. Per‑env is a potential future extension.
- What if CI can’t sign yet? Keep `require_signed=false` until CI’s key is provisioned. You can still enforce fast‑forward and authors via policy.

## Planned: Setup Wizard

A guided `git shiplog setup` flow will help you pick a strictness level, write a starter policy, publish the policy ref, and (optionally) bootstrap trust now or later. It will also print server guidance for the hook and relaxed bootstrap variables.

