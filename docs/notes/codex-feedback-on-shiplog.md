# Shiplog DX Notes — September 2025

I took Shiplog for a (manual) spin today in order to integrate it with the PF3 deploy orchestrator. These are the rough notes I’d want any future maintainer to have — both what felt rock-solid and what I’d polish next.

---

## Overall Impression

Shiplog already feels *production ready* for the git-native audit log niche it targets. The primitives — signed commits under `refs/_shiplog/journal/<env>` with structured trailers — map perfectly onto the “what happened in prod?” question we ask ourselves during incidents. Once trust/bootstrap is in place, `git shiplog write` feels just as natural as `git commit`.

I’d happily depend on it for:

- Deploy receipts (start → step → finish)
- Maintenance mode toggles (with reasons / reminders)
- RBAC changes (added admin, revoked key)
- Trust rotations & secret rotations
- Ad-hoc scripts with log capture (once `shiplog run` lands)

In other words: if an operator does something that changes prod, Shiplog is the canonical place to record it. That’s exactly what I want from an operational journal.

---

## Things That Felt Great

- **Git-first workflow**: No extra service. Journals are just refs. Easy to mirror, easy to inspect.
- **Signing/Policy hooks**: Guard rails are strong. Missing trust ref immediately fails with a helpful message. SSH signing plays nicely with modern git.
- **Structured trailers**: The JSON we get back from `git shiplog show --json` is deliciously parseable. Perfect for piping into dashboards or incident bots.
- **Trust tooling**: `shiplog-bootstrap-trust.sh` + `shiplog-trust-sync.sh` made the initial setup straightforward. Non-interactive flags mean we can script it.
- **Docs/AGENTS discipline**: The repo has clearly codified expectations (test in Docker, etc.). Easy to onboard to.

---

## Opportunities / DX Wishlist

### 1. `git shiplog run` (on deck)
Exactly what we’re about to build: wrap a command, tee stdout/stderr, and attach the log as a note. I’d ship it with:
- `--service`, `--reason`, `--status-success/failed` overrides.
- Structured `run` payload: `argv`, `cmd`, `exit_code`, `status`, `duration_s`, `started_at`, `finished_at`.
- Boring mode by default; interactive tee for humans.
- Respects `SHIPLOG_NAMESPACE`, `SHIPLOG_TICKET`, etc., so we can categorize maintenance vs deploy vs misc.

### 2. Programmatic API helper
Either a `git shiplog append --json payload` or a tiny shell helper that sets `SHIPLOG_EXTRA_JSON` and calls `write`. That would keep deploy-orchestrator code simpler.

### 3. Namespace defaults
`git shiplog ls` shows `Env` as `?` unless `SHIPLOG_NAMESPACE` is set. Defaulting the namespace to the journal name (or providing a `--namespace` flag) would make the table friendlier.

### 4. Trust roster visibility
A `git shiplog trust show` command that prints threshold and maintainer list would be handy during audits.

### 5. Docs: runbook for operators
Once `shiplog run` is available, a short runbook (“How to log maintenance mode”, “How to record an incident”, “How to rotate trust”) would accelerate adoption.

---

## Integration Notes (PF3)

For PF3 we intend to:
- Emit a Shiplog entry when a deploy plan is approved (status=started + plan JSON).
- Append entries after each step (`status` `in_progress`, `reason` summarizing action, structured run payload).
- Finish with a `status=success|failed` entry containing maintenance flag, failure reason, etc.
- Use `shiplog run` for ad-hoc maintenance toggles or recovery scripts so we capture raw command output automatically.

That will replace our ad-hoc JSON journal with a tamper-evident history.

---

## Misc Observations

- **Trust bootstrap** refused to run outside a repo. Nice guard! Perhaps the script could detect this earlier and print “run inside target repo” with the resolved path.
- **Preview output** always prints (even in `--yes`). I like that, but a `SHIPLOG_NO_PREVIEW=1` toggle might be nice for CI logs.
- **`SHIPLOG_EXTRA_JSON`** hook was easy to splice in once I noticed trailers are composed in `compose_message`. Reusing `shiplog_json_escape` will keep it tidy when I refactor the helper.
- **Testing** via `make test` (Docker) was smooth. Love that the AGENTS doc shouts *not* to run tests directly.

---

## Other Potential Use Cases

- **Incident timeline**: `git shiplog run --service incident --reason "Declared SEV-1" -- env true` to mark major steps.
- **Access review**: Append entries whenever someone is added/removed from Supabase roles or GitHub teams.
- **Secrets rotation**: Wrap rotation scripts with `shiplog run` so we have an audit trail of the exact CLI output.
- **Schema migrations**: Each `supabase db push` could be wrapped to capture the migration log.
- **Build provenance**: If we wanted to record Docker image builds (“built ghcr.io/app@sha…”) we could make `shiplog run` a standard part of the release pipeline.

---

## Closing Thoughts

Shiplog is already delivering on the “black box recorder for ops” promise. The biggest DX win on the horizon is the command wrapper — once we have that, we can eliminate a ton of bespoke logging code across projects. Happy to help keep pushing it forward!

