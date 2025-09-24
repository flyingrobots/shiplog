# Trust Bootstrap and Enforcement

Shiplog keeps the signer roster and policy under signed Git references so every promotion is auditable.
This guide explains the one-time bootstrap, how to mirror trust material, and how to keep local
installations in sync.

## jq Requirement

All trust and policy validation uses `/usr/local/bin/jq` pinned to version `1.7.1`. Containers, CI, and server hooks should install exactly that build (with checksum verification). Running hooks outside the container must use the same version to avoid schema drift.

```bash
# Dockerfile snippet
ARG JQ_VERSION=1.7.1
curl -fsSL -o /usr/local/bin/jq \
  "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64"
echo "b21d1a42bfcab948e76f22aa8775d1d86c98cd63f6395f9a9eeb0d4f58af0a4c  /usr/local/bin/jq" \
  | sha256sum -c -
chmod +x /usr/local/bin/jq
/usr/local/bin/jq --version
```

## One-Time Trust Bootstrap

Bootstrap is the only moment you may bypass quorum checks. After the initial push, every update to `refs/_shiplog/trust/root` must be fast-forward and co-signed by the current threshold of maintainers.

### Fast Path: `scripts/shiplog-bootstrap-trust.sh`

Run the helper to collect maintainer metadata, generate `.shiplog/trust.json` and `.shiplog/allowed_signers`, create the signed genesis commit, and optionally push it to origin:

```bash
./scripts/shiplog-bootstrap-trust.sh           # prompts for maintainer roster and SSH keys
./scripts/shiplog-bootstrap-trust.sh --no-push # prepare locally, push later
```

The script will:

1. Prompt for maintainer names, emails, roles, optional OpenPGP fingerprints, and SSH public keys.
2. Build a JSON manifest with the chosen signature threshold.
3. Write `.shiplog/trust.json` and `.shiplog/allowed_signers` (backing up existing files unless `--force`).
4. Create and sign the genesis commit for `refs/_shiplog/trust/root`.
5. Offer to push the new ref to `origin`.

After the script completes (and you push the ref, if desired), distribute the roster with `./scripts/shiplog-trust-sync.sh` so every workstation and CI runner receives the generated `allowed_signers` file.

### Manual Bootstrap (detailed)

```bash
# 0) Prepare trust material (ideally on an offline machine)
cat > .shiplog/trust.json <<'JSON'
{ "version": 1, "id": "shiplog-trust-root", "threshold": 2,
  "maintainers": [
    {"name": "Alice", "email": "alice@example.com", "pgp_fpr": "AAAA...1111", "role": "root", "revoked": false},
    {"name": "Bob",   "email": "bob@example.com",   "pgp_fpr": "BBBB...2222", "role": "root", "revoked": false}
  ]
}
JSON
cat > .shiplog/allowed_signers <<'SIGS'
alice@example.com AAAAC3Nz...alice-key...
bob@example.com   AAAAC3Nz...bob-key...
SIGS

# 1) Write a tree with the trust artifacts
OID_TRUST=$(git hash-object -w .shiplog/trust.json)
OID_SIGS=$(git hash-object -w .shiplog/allowed_signers)
TREE=$(printf "100644 blob %s\ttrust.json\n100644 blob %s\tallowed_signers\n" "$OID_TRUST" "$OID_SIGS" | git mktree)

# 2) Create the genesis commit (each maintainer signs the same tree)
GENESIS=$(echo "shiplog: trust root v1 (GENESIS)" |
  GIT_AUTHOR_NAME="Trust Init" GIT_AUTHOR_EMAIL="trust@local" \
  git commit-tree "$TREE" -S)

# 3) Install the ref (server allows this only when the ref is absent)
git update-ref refs/_shiplog/trust/root "$GENESIS"
git push origin refs/_shiplog/trust/root
```

After bootstrap, the server hook must reject any trust update that is not a fast-forward or lacks the required number of maintainer signatures. Document this expectation in your repo policies so nobody attempts another bypass.

## Keeping Clients in Sync

Use the helper script to materialize the allowed signers from the trust ref and teach Git where to find it. This avoids copying unsigned files or relying on repository checkout state.

```bash
./scripts/shiplog-trust-sync.sh                    # defaults to refs/_shiplog/trust/root → .shiplog/allowed_signers
./scripts/shiplog-trust-sync.sh refs/_shiplog/trust/root ~/.config/shiplog/allowed_signers
```

The script fetches the latest trust ref (you still need `git fetch` beforehand), reads `allowed_signers` from the signed commit, writes it to the chosen destination, and sets `gpg.ssh.allowedSignersFile` to point at that file.

## Server Enforcement Checklist

* Fail fast when the trust ref or `trust.json` is missing (`❌ SHIPLOG: trust ref missing`).
* Validate trust.json and policy.json with the pinned jq.
* Require the trust commit to be co-signed by at least the threshold maintainers (after bootstrap).
* Require policy updates to be signed by a maintainer listed in `trust.json` and keep them fast-forward.
* When journal entries arrive:
  * Enforce fast-forward pushes.
  * Verify commit signatures against the signer roster from the trust ref.
  * Parse the JSON trailer to ensure `trust_oid`, `journal_parent`, `seq`, and required WWWWWH fields
    match policy.
  * Compare `trust_oid` to the current server trust tip to prevent stale-trust replays.
* Mirror `refs/_shiplog/{trust,policy,journal}` to a second remote or WORM storage for recovery.

## Solo Maintainer Trust Setup

When you are the only maintainer, avoid a single point of failure by creating multiple, independent signing identities that you control and using a threshold greater than 1:

- Primary SSH signing key on your laptop (passphrase‑protected).
- Hardware token SSH signing key (e.g., YubiKey) as a second factor.
- CI SSH signing key stored in a protected GitHub Environment as a third identity.

Set `threshold` to 2 (2‑of‑3). This allows signing in CI even if your laptop is offline, and vice versa, and enables quick rotation if a key is compromised.

Example maintainer entries in `trust.json`:

```
{
  "version": 1,
  "id": "shiplog-trust-root",
  "threshold": 2,
  "maintainers": [
    { "name": "Maintainer", "email": "you@example.com", "pgp_fpr": "<40-hex or null>", "role": "root", "revoked": false },
    { "name": "CI",         "email": "ci@example.com",  "pgp_fpr": null,           "role": "root", "revoked": false },
    { "name": "YubiKey",    "email": "you@example.com", "pgp_fpr": null,           "role": "root", "revoked": false }
  ]
}
```

The corresponding `allowed_signers` should include one line per SSH key (principal + key).

Notes:
- Use real, monitored email addresses. Avoid placeholders.
- Prefer SSH signing for CI and hardware tokens. Provide a PGP fingerprint only when you actually use PGP to sign.
- Document where these keys live, how to unlock them, and who is allowed to rotate them.

## Emergency Recovery

If you lose access to one or more keys or need to rotate quickly:

- Add a new maintainer/key:
  - Update `trust.json` and `allowed_signers` with the new key/principal.
  - Create a new trust commit (fast‑forward) and push `refs/_shiplog/trust/root`.

- Remove or revoke a compromised maintainer/key:
  - Either remove the maintainer entry, or set `revoked: true` and remove its line from `allowed_signers`.
  - Create and push a trust update as above.

- Change the threshold:
  - Edit `threshold` in `trust.json`, then create and push a trust update.

- Out‑of‑band update (bare repo admin only):
  - In rare cases (e.g., all keys lost), an admin on the bare repository can write a new trust commit directly with `git --git-dir … update-ref`. Use this sparingly, record the reason in your audit log, and immediately re‑establish a healthy threshold and signer set.

Always follow up with `./scripts/shiplog-trust-sync.sh` on all workstations and runners to install the updated `allowed_signers` and point `gpg.ssh.allowedSignersFile` to it.

## Recommended Runbook Entries

See also `docs/runbooks/release.md`:1 for an end‑to‑end “use Shiplog to release Shiplog” flow including common failure paths and a CI outline.

See the runbook appendix in the README for detailed “what if” responses covering key loss, trust rotation,
and mirror recovery.
