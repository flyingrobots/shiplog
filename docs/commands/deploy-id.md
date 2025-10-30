# shiplog-deploy-id

Generate a sortable Deployment ID and optionally export it for the current shell so that every subsequent Shiplog entry is stamped with the same ID.

## Usage

```bash
# Print an ID (ULID if available; else UUID; else timestamp+sha fallback)
scripts/shiplog-deploy-id.sh

# Export it into your shell for this session
eval "$(scripts/shiplog-deploy-id.sh --export)"

# Now stamp every step of your deployment automatically
git shiplog run --service web -- bash -lc 'prechecks'
git shiplog run --service web -- bash -lc 'rollout'
git shiplog write --service web --status finalize --reason "done"

# Replay just those entries later
scripts/shiplog-replay.sh --env prod --deployment "$SHIPLOG_DEPLOY_ID" --step
```

## Options

- `--export|-x` — Print `export SHIPLOG_DEPLOY_ID=<id>` so you can `eval` it.
- `--id <value>` — Provide your own ID (skips minting).
- `--help` — Show usage.

## Notes

- The Deployment ID is also mirrored into `why.ticket` when you don’t provide a ticket, for backward compatibility with existing consumers.
- You can also pass a Deployment ID directly on any `run/write/append` via `--deployment <id>`.

