# SHIPLOG • 🚢🪵

## Friday, 3:17 PM

*Bzzzt. Bzzzzzt. Bzzzzzzzzt.*

The intern looks like they just saw a ghost.
The dashboards flip from green to red.  
Slack explodes.  
Bob mutters, “It worked on my laptop.”  
The CI logs stop mid-sentence.  
Jenkins, the poor old man, quietly running the same cron jobs since 2019, is suddenly a suspect. 

You’re about to dive into six different dashboards to piece together the truth when you remember: **We use Shiplog.**

In a flash, you run a single command and the chaos dissolves. 

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

Shiplog is your deployment black box recorder. Think `git commit` — but for releases. Every deployment leaves a cryptographically signed receipt in Git. Human-readable, machine-parseable, tamper-evident.

Why you want it:

- 🧑‍💻 Readable: Debug at 3 a.m. without archeology.
- 🤖 Parseable: Pipe JSON to dashboards, alerts, or bots.
- 🔏 Signed: Clear provenance and compliance.
- 🪢 Git-native: No infra. No SaaS. Just commits.

### 📦 Philosophy

Shiplog isn’t another deployment platform.
It’s a primitive. A receipt. A ledger.
Build your workflows around it, same way you build around git commit.

No dashboards. No archaeology. Just clarity.

---

## 🚀 Getting Started

```bash
git clone https://github.com/flyingrobots/shiplog.git "$HOME/.shiplog"
export SHIPLOG_HOME="$HOME/.shiplog"
export PATH="$SHIPLOG_HOME/bin:$PATH"
"$SHIPLOG_HOME/install-shiplog-deps.sh"
```

Verify install:

```bash
git shiplog --version
```

---

## 🛠️ Basic Usage

Initialize in your repo:

```bash
cd your-project
git shiplog init
```

*(NOTE: See [docs/TRUST.md](docs/TRUST.md) for one-time policy and trust setup instructions)*

Record a deployment event:

```bash
export SHIPLOG_ENV=prod
export SHIPLOG_SERVICE=web
git shiplog write
```

Inspect history:

```bash
git shiplog ls --env prod
git shiplog show --json
```

Pipe to tools:

```bash
git shiplog export-json | jq .
```

Wrap a command and capture its output automatically:

```bash
git shiplog run --service deploy --reason "Canary" -- env kubectl rollout status deploy/web
```

Append structured data non-interactively (great for automation):

```bash
printf '{"checks": {"canary": "green"}}' | \
  git shiplog append --service deploy --status success --reason "post-release smoke" --json -
```

---

## 🔐 Policy & Security

Shiplog enforces policy as code, stored in Git itself.

- `refs/_shiplog/journal/<env>` → append-only logs
- `refs/_shiplog/policy/current` → signed policy refs
- Optional strict mode: signed commits per-env (e.g., prod only)

### Example policy (`.shiplog/policy.json`)

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

---

## ⚙️ Core Commands

| Command |	Purpose |
|---------|---------|
| `git shiplog init` |	Setup refs & configs |
| `git shiplog write` |	Record a deployment |
| `git shiplog append` |	Record a deployment via JSON payload (stdin or file) |
| `git shiplog run` |	Wrap a command, capture logs, and record result |
| `git shiplog ls` |	List recent entries |
| `git shiplog show` |	Show entry details |
| `git shiplog trust show` |	Display trust roster and signer inventory |
| `git shiplog verify` |	Verify signatures/allowlist |
| `git shiplog export-json` |	Export NDJSON for tools |

---

## 🧪 Testing

> [!WARNING]
> ⚠️ **Shiplog developers**: Avoid running Shiplog in its own repo path. Shiplog mutates Git refs! By default, tests are configured to run in a Docker container. Use it!

```bash
make test         # Unsigned, fast
make test-signing # With loopback GPG key
```

---

## 📜 License

MIT © J. Kirby Ross • @flyingrobots

*Jenkins was not harmed in the making of this project.*
