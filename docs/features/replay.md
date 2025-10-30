# Replay (Experimental)

`scripts/shiplog-replay.sh` replays a sequence of Shiplog entries from a journal and prints their summaries and (optionally) attached logs. This is useful when you want to review a deployment that involved multiple steps and watch the captured output in order.

## TL;DR

```bash
# Last 5 entries in prod, paced by recorded durations
scripts/shiplog-replay.sh --env prod

# Fastest replay (no sleeps) of the last 10 entries in staging
scripts/shiplog-replay.sh --env staging --count 10 --speed 0

# Step through a specific range (inclusive), showing logs
scripts/shiplog-replay.sh --env prod --from <old-sha> --to <new-sha> --step

# Compact mode (no trailer JSON), suppress logs
scripts/shiplog-replay.sh --env prod --count 20 --compact --no-notes

# Replay a specific deployment by ID (or ticket)
scripts/shiplog-replay.sh --env prod --deployment "$SHIPLOG_DEPLOY_ID" --speed 0
# alias: --ticket <id>
```

## Behavior

- Prints a concise header for each entry with `service`, `env`, `status`, `seq`, timestamp, author, and repo head.
- When available, prints the JSON trailer (`jq -C -S .`) so you can see the structured fields captured for each entry.
- If a git note (log) is attached, prints it between `--- log (notes) ---` and `--- end log ---`.
- Paces output using the recorded run duration (when present) and a `--speed` multiplier.
  - `--speed 1.0` (default): roughly real time, capped to short sleeps between entries.
  - `--speed 0`: fastest replay (no sleeps).
- `--step` pauses between entries and waits for Enter instead of sleeping.

## Options

- `--env <name>` — Journal environment (default: `prod` or `SHIPLOG_ENV`).
- `--from <sha>` — Start at this commit (inclusive). If omitted, starts at the latest.
- `--to <sha>` — Stop at this commit (inclusive).
- `--count <n>` — Maximum number of entries (default `5`).
- `--speed <x>` — Speed multiplier for pacing (`1.0` = real time-ish, `0` = fastest).
- `--no-notes` — Do not print attached logs.
- `--compact` — Do not print the trailer JSON, only the entry header.
- `--step` — Step through entries interactively.
- `--deployment <id>` — Replay only entries stamped with `deployment.id=<id>` (or with back‑compat `why.ticket=<id>`). Alias: `--ticket <id>`.

## Convenience Sources

- `--since-anchor` (portable): use the last anchor for the environment as the start boundary and the current journal tip as the end.
- `--pointer <ref>` (local convenience): resolve `<ref>@{1}..@{0}` from the local reflog; handy for a “last deployment” pointer like `refs/_shiplog/deploy/prod`.
- `--tag <name>`: equivalent to `--pointer refs/tags/<name>` and depends on tag reflogs.

## Notes & Limitations

- Logs attached as git notes are printed as saved; per-line timestamps aren’t preserved, so intra-log pacing is approximated uniformly.
- This helper is read-only; it does not modify Shiplog refs or your repository state.
- Requires `jq` and `git`.

## See Also

- `git shiplog ls`, `git shiplog show` — inspect individual entries.
- `git shiplog export-json` — stream trailer JSONs as NDJSON for custom tooling.
- `docs/features/run.md` — structured `run` payload captured by `git shiplog run`.
