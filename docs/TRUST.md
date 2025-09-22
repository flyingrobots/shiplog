# Trust Bootstrap and Enforcement

Shiplog keeps the signer roster and policy under signed Git references so every promotion is auditable.
This guide explains the one-time bootstrap, how to mirror trust material, and how to keep local
installations in sync.

## jq Requirement

All trust and policy validation uses `/usr/local/bin/jq` pinned to version `1.7.1`. Containers, CI, and
server hooks should install exactly that build (with checksum verification). Running hooks outside the
container must use the same version to avoid schema drift.

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

Bootstrap is the only moment you may bypass quorum checks. After the initial push, every update to
`refs/_shiplog/trust/root` must be fast-forward and co-signed by the current threshold of maintainers.

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

After bootstrap, the server hook must reject any trust update that is not a fast-forward or lacks the
required number of maintainer signatures. Document this expectation in your repo policies so nobody
attempts another bypass.

## Keeping Clients in Sync

Use the helper script to materialise the allowed signers from the trust ref and teach Git where to find
it. This avoids copying unsigned files or relying on repository checkout state.

```bash
./scripts/shiplog-trust-sync.sh                    # defaults to refs/_shiplog/trust/root → .shiplog/allowed_signers
./scripts/shiplog-trust-sync.sh refs/_shiplog/trust/root ~/.config/shiplog/allowed_signers
```

The script fetches the latest trust ref (you still need `git fetch` beforehand), reads
`allowed_signers` from the signed commit, writes it to the chosen destination, and sets
`gpg.ssh.allowedSignersFile` to point at that file.

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

## Recommended Runbook Entries

See the runbook appendix in the README for detailed “what if” responses covering key loss, trust rotation,
and mirror recovery.
