# shiplog-replay (experimental)

Replays Shiplog entries as a linear “story” for a given environment, deployment ID, or range. Prints a concise header for each entry, optional trailer JSON, and any attached log note (paced by recorded durations).

## Usage

```bash
# Last 5 entries in prod, roughly real time
scripts/shiplog-replay.sh --env prod

# Fast replay (no sleeps) of the last 10 entries
scripts/shiplog-replay.sh --env staging --count 10 --speed 0

# Step through a specific window (inclusive)
scripts/shiplog-replay.sh --env prod --from <old-sha> --to <new-sha> --step

# Replay just one deployment by ID (or ticket)
scripts/shiplog-replay.sh --env prod --deployment "$SHIPLOG_DEPLOY_ID"
# alias: --ticket <id>
```

## Options

- `--env <name>`: Journal environment (default: `prod` or `SHIPLOG_ENV`).
- `--from <sha>` / `--to <sha>`: Inclusive range; accepts refs.
- `--count <n>`: Limit the number of entries (default 5; ignored when `--deployment` set).
- `--speed <x>`: Pacing multiplier (1.0 ≈ real time; 0 = no sleeps).
- `--step`: Wait for Enter between entries instead of sleeping.
- `--compact`: Print only the header (omit trailer JSON).
- `--no-notes`: Do not print attached logs.
- `--deployment <id>`: Filter to entries with `deployment.id=<id>` (or legacy `why.ticket=<id>`). Alias: `--ticket <id>`.

## Notes

- Read-only: this helper does not modify refs.
- Pacing is approximated uniformly across the log when a run duration is present.
- Requires `jq` and `git`.

## See Also

- `docs/features/replay.md` — Additional examples and behavior details.
- `scripts/shiplog-deploy-id.sh` — Mint a sortable Deployment ID.

