# git shiplog replay (wrapper) and shiplog-replay (script)

Replays Shiplog entries as a linear “story” for a given environment, deployment ID, or range. Prints a concise header for each entry, optional trailer JSON, and any attached log note (paced by recorded durations).

## Usage

```bash
# First-class command (preferred):
git shiplog replay --deployment "$SHIPLOG_DEPLOY_ID" --env prod --step
git shiplog replay --since-anchor --env prod
git shiplog replay --pointer refs/_shiplog/deploy/prod --env prod
git shiplog replay --tag deploy/prod --env prod

# Under the hood: the wrapper delegates to the script
scripts/shiplog-replay.sh --env prod --count 10 --speed 0
scripts/shiplog-replay.sh --env prod --from <old-sha> --to <new-sha> --step
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
- `--since-anchor`: Use the last anchor as start and the current journal tip as end.
- `--pointer <ref>`: Use `<ref>@{1}..@{0}` as the window (local reflog convenience).
- `--tag <name>`: Shortcut for `--pointer refs/tags/<name>`.

## Notes

- Read-only: this helper does not modify refs.
- Pacing is approximated uniformly across the log when a run duration is present.
- Requires `jq` and `git`.

## See Also

- `docs/features/replay.md` — Additional examples and behavior details.
- `scripts/shiplog-deploy-id.sh` — Mint a sortable Deployment ID.
