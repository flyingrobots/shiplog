# SHIPLOG • 🚢🪵

The pager goes off at 3:17 a.m.
The intern is frozen, hands hovering over the keyboard like it’s wired with C4.
And of course, you picked this week to quit smoking.

The coffee pot’s empty. Of course it is. You quit coffee too, because you’re a genius.
The dashboards are bleeding red.
Slack is twelve parallel arguments, all noise, no answers.

The monitoring alert reads like a ransom note — all caps, no punctuation, and somehow it knows your name.
The runbook is 400 pages long. Step one: panic.

Bob mutters, “It worked on my laptop.”
Bob’s laptop hasn’t been patched since the Obama administration.

The Jira ticket’s still “In Review.”
That’s funny, because prod isn’t.

The CI logs stop mid-sentence.
Last line: “Deploying…” Nothing else. Just static.

And in the corner, Jenkins is whispering again.
He’s been mumbling the same cronjob lullaby since 2019.
Nobody listens — until prod catches fire, and suddenly the old man’s a suspect.

Stop blaming the ghost. Stop digging through rubble.

All of the ship is logged in Git.

Zero infra. No new tools.
Lives by your code.

No archaeology.
No copy/paste.
No 2FA hopscotch through three dashboards.

Just clarity.
And the truth.

*INT. WAR ROOM – DAWN*

The intern finally exhales, hands unclenched.
Slack arguments dissolve into praise.
Bob swears he’ll upgrade Jenkins — “just in case.”

Yeah, right.

The room is calm again.
The intern looks at you, wide-eyed:

“How’d you figure it out so fast?”

You smirk, close the laptop, and say:

**“Simple. Get Shiplog.”**

## 🚢 What Is Shiplog?

Shiplog is your deployment black box recorder. Every release leaves a cryptographic receipt.

You don't have to leave the terminal to find out who, what, where, when, why, and how your deployments were made.

### Use Shiplog for Future You

- **Human-readable**: Helps when you're debugging at 3 a.m.
- **Machine-parseable**: For your monitoring tools and dashboards.
- **Cryptographically signed**: For compliance and clear provenance.
- **Git-native**: It follows your code everywhere.

### What Makes Shiplog Different

Shiplog isn't another deployment platform, it's a primitive. Build with it. Think `git commit` for deployments. It gives you the essential building block (cryptographic receipts) that you can use to build whatever workflows your team needs.

Because it's built on Git, you get:

- **Zero new infrastructure**: No databases, no services.
- **Distributed by default**: It works offline and syncs everywhere.
- **Tamper-evident**: Signed commits and append-only refs prevent history rewriting.
- **Familiar tooling**: Use familiar commands like `git log` and `git show`.

```mermaid
gitGraph
  commit id: "feat: add auth" tag: "main"
  commit id: "fix: handle errors"
  branch shiplog_prod
  commit id: "✅ web v2.1.3 → prod"
  commit id: "❌ api v1.4.2 → prod"
  commit id: "🔄 rollback web v2.1.2"
```

## 🚀 Quickstart

There are a few ways to get started.

### Quick Install (Recommended)

1. Clone the repository:

```Bash
git clone https://github.com/flyingrobots/shiplog.git "$HOME/.shiplog"
```

2. Update your shell configuration (`~/.bashrc`, `~/.zshrc`, etc.):

```Bash
export SHIPLOG_HOME="$HOME/.shiplog"
export PATH="$SHIPLOG_HOME/bin:$PATH"
```

3. Reload your shell and verify: `shiplog --help`

4. Install dependencies:

```Bash
"$SHIPLOG_HOME/install-shiplog-deps.sh"
```

## Basic Usage

Once installed, you can initialize a repo and start recording deployments.

```Bash
# Initialize in your repo
cd your-project
git shiplog init

# Record your first deployment
export SHIPLOG_ENV=prod
export SHIPLOG_SERVICE=web
git shiplog write

# View your deployment history
git shiplog ls --env prod
git shiplog show $(git rev-parse refs/_shiplog/journal/prod)

# Non-interactive (CI) mode
# Use `SHIPLOG_BORING=1` to disable interactive prompts
SHIPLOG_BORING=1 git shiplog write

# Export for your monitoring tools
git shiplog export-json --env prod | jq '.'
```

## 🛠️ How It Works

Shiplog records deployment events as signed empty-tree commits to a set of hidden Git refs. This makes the ledger tamper-evident and keeps it separate from your main branch history.

- Journals: `refs/_shiplog/journal/<env>` are append-only, fast-forward only logs for each environment.
- Anchors: `refs/_shiplog/anchors/<env>` can be used to mark a last known good state.
- Notes: `refs/_shiplog/notes/logs` are optional NDJSON attachments for logs or other metadata.

## ⚙️ Core Commands

| Command | Purpose | Example |
| :--- | :--- | :--- |
| `git shiplog init` | Setup refspecs & reflog configs | `git shiplog init` |
| `git shiplog write` | Record a deployment | `git shiplog write` |
| `git shiplog ls` | List recent entries | `git shiplog ls --env prod --limit 5` |
| `git shiplog show` | Show entry details | `git shiplog show <commit>` |
| `git shiplog verify` | Check signatures + author allowlist | `git shiplog verify --env prod` |
| `git shiplog export-json` | NDJSON export for external tools | `git shiplog export-json \| jq '.'` |

## 🔐 Security & Policy

Shiplog's security model is based on policy-as-code, stored and enforced within Git itself.

### Policy Lives in Git Itself

- **Canonical ref**: `refs/_shiplog/policy/<env>` are signed commits containing your `.shiplog/policy.yaml` files.
- **Mirror in main branch**: A copy of the policy file lives on your `main` branch, allowing changes to go through the normal PR review process.
- **CI sync script**: A script (`scripts/shiplog-sync-policy.sh`) fast-forwards the policy ref after a merge, ensuring the enforced policy is always what's been reviewed and approved.

### Example Policy File (`.shiplog/policy.json`)

```JSON
{
  "version": 1,
  "require_signed": true,
  "allow_ssh_signers_file": ".git/allowed_signers",
  "authors": {
    "default_allowlist": [
      "deploy-bot@ci",
      "james@flyingrobots.dev"
    ],
    "env_overrides": {
      "prod": [
        "deploy-bot@ci",
        "james@flyingrobots.dev"
      ]
    }
  },
  "deployment_requirements": {
    "prod": {
      "require_ticket": true,
      "require_service": true,
      "require_where": [
        "cluster",
        "region",
        "namespace"
      ]
    },
    "default": {
      "require_ticket": false
    }
  },
  "ff_only": true,
  "notes_ref": "refs/_shiplog/notes",
  "journals_ref_prefix": "refs/_shiplog/journal/",
  "anchors_ref_prefix": "refs/_shiplog/anchors/"
}
```

## 🧪 Testing

Shiplog uses make and bats to run its test suite.

```Bash
# Unsigned (fast, CI-friendly)
make test

# Signed (loopback GPG key)
make test-signing
```

### Coverage:

- Init wiring (refspecs + reflogs)
- Write flow + ls/show rendering
- Export-JSON + notes attachments
- Verify logic across unsigned/signed entries
- Fast-forward-only guardrails

### Requirements

- Git ≥ 2.x (with signing configured)
- Bash 3.2+ shell
- jq for JSON processing
- GPG or SSH signing key
  
## License

MIT © J. Kirby Ross • [@flyingrobots](https://github.com/flyingrobots)

_Jenkins was not harmed in the making of this project._
