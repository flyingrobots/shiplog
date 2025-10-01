## 🚢🪵 Shiplog: Your Git Repo is Your Deployment Black Box Recorder

**TL;DR:** Your deployment history should live in the same repo as your code. No external services. No API keys. No monthly bills. Just **Git**, doing what it does best: preserving history with cryptographic integrity.

---

## The Chaos Scenario: Friday, 3:17 PM

*Bzzzt. Bzzzzzt. Bzzzzzzzzt.* The intern looks like they just saw a ghost. Dashboards flip from green to red. Slack explodes. Bob mutters, "It worked on my laptop."

You're about to dive into six different dashboards to piece together the truth when you remember: **We use Shiplog.**

In a flash, you run a single command and the chaos dissolves:

```bash
git shiplog show
┌ SHIPLOG Entry ────────────────────────────────────────────────┐
│ Deploy: boring-web v1.2.3 → prod/us-east-1/prod-a/default     │
│ Reason: Starting Migration...                                 │
│ Status: FAILURE (7m12s) @ 2025-09-21T22:38:42Z                │
└───────────────────────────────────────────────────────────────┘
```

The truth is revealed: a failed migration, a clear timestamp, and the exact commit that triggered it.

---

## ✨ What Is Shiplog?

Shiplog is your deployment **black box recorder**. Think `git commit`—but for every release and live-ops event. Every deployment leaves a cryptographically signed receipt in Git.

### The Philosophy

Shiplog isn’t another deployment platform. It’s a **primitive**: a receipt, a ledger. Build your automated workflows around it, the same way you build around `git commit`.

**Why you want it:**

- 🧑‍💻 **Readable:** Debug deployments at 3 a.m. without archeology.
- 🤖 **Parseable:** Pipe machine-readable JSON to dashboards, alerts, or bots.
- 🔏 **Signed:** Clear provenance and compliance via commit signing.
- 🪢 **Git-Native:** No infra. No SaaS. **Just Git commits.**

### Git: An Immutable, Distributed Journal

Git **_is_** a data structure. Shiplog uses it to create chains of commits that hang off of dedicated references (`refs/_shiplog/*`), forming an **append-only journal**. Git is powerful; it can do way more than just source control.

---

## 🔐 Policy, Security, and Trust

**Don't Trust; Verify.** Shiplog establishes cryptographic provenance for every record and enforces policy _as code_, stored as a commit in your Git repository.

- **Trust Roster:** A list of approved authors is stored in Git, restricting who may write to the journal.
- **Policy by Quorum:** Policies themselves require a quorum of authorized signers to change.
- **Cryptographic Provenance:** Commit authors **sign their commits** to establish who created each record, perfect for auditable histories.

### Example Policy (`.shiplog/policy.json`)

```json
{
  "require_signed": true,
  "authors": {
    "prod": ["deploy-bot@ci", "james@flyingrobots.dev"]
  },
  "deployment_requirements": {
    "prod": { "require_ticket": true }
  }
}
```

- `refs/_shiplog/journal/<env>` → Append-only logs for each environment.
- `refs/_shiplog/policy/current` → Signed policy references.

---

## 🚀 Getting Started

It's all just Git! You can fetch, push, clone, and verify using tools and knowledge you already have.

### Installation

```bash
git clone https://github.com/flyingrobots/shiplog.git "$HOME/.shiplog"
export SHIPLOG_HOME="$HOME/.shiplog"
export PATH="$SHIPLOG_HOME/bin:$PATH"
"$SHIPLOG_HOME/install-shiplog-deps.sh"
```

**Verify install:**

```bash
git shiplog --version
```

### Basic Usage

1. Initialize Shiplog in your repository:

```bash
cd your-project
git shiplog init
```

_(NOTE: See [`docs/TRUST.md`](docs/TRUST.md) for one-time policy and trust setup instructions)_
   
2. Record a deployment event:

```bash
export SHIPLOG_ENV=prod
export SHIPLOG_SERVICE=web
git shiplog write
```
 
3. Inspect history:

```bash
git shiplog ls --env prod
git shiplog show --json
```
   
4. Wrap a command and capture its output automatically:

```bash
git shiplog run --service deploy --reason "Canary" -- env kubectl rollout status deploy/web
```
 
5. Append structured data non-interactively (great for automation):

```bash
printf '{"checks": {"canary": "green"}}' | \
  git shiplog append --env prod --region us-west-2 --cluster prod-a \
	--namespace frontend --service deploy --status success \
	--reason "post-release smoke" --json -
``` 

---

## ⚙️ Core Commands

|Command|Purpose|
|---|---|
|`git shiplog init`|Setup references (`refs`) and configuration.|
|`git shiplog write`|Record a deployment interactively.|
|`git shiplog append`|Record a deployment via JSON payload (stdin or file).|
|`git shiplog run`|Wrap a command, capture logs, and record the result.|
|`git shiplog ls`|List recent entries.|
|`git shiplog show`|Show entry details.|
|`git shiplog trust show`|Display trust roster and signer inventory.|
|`git shiplog verify`|Verify signatures and policy compliance.|
|`git shiplog export-json`|Export NDJSON for tools.|

---

## 🧪 Testing

> ⚠️ **Warning to Shiplog Developers:** Avoid running Shiplog in its own repository path. Shiplog mutates Git refs! By default, tests are configured to run in a Docker container. Use it!

```bash
make test         # Unsigned, fast
make test-signing # With loopback GPG key
```

---

## 📜 License

MIT © J. Kirby Ross • [@flyingrobots](https://github.com/flyingrobots)

_Jenkins was not harmed in the making of this project._
