# Export JSON Command

## Summary
`git shiplog export-json` emits NDJSON records for journal entries so downstream systems can ingest Shiplog data. Each line combines the stored JSON trailer with the commit SHA in a `commit` field.

## Usage
```bash
git shiplog export-json [ENV] | jq '.'
```

## Behavior
- Requires `jq` to be available.
- Streams commits in reverse chronological order and appends a `commit` field to each JSON payload.
- Uses the same environment resolution rules as other commands (argument, `--env`, `SHIPLOG_ENV`, default `prod`).

## Filtering by Deployment ID or Ticket

```bash
# All commits for a given deployment id (preferred)
DEPLOY_ID="REL-2025-10-30.1"
git shiplog export-json prod \
  | jq -r --arg id "$DEPLOY_ID" 'select((.deployment.id // "") == $id) | .commit'

# Back-compat by ticket
git shiplog export-json prod \
  | jq -r --arg id "$DEPLOY_ID" 'select((.why.ticket // "") == $id) | .commit'
```

Tip: pass these through the replay command to “page” a deployment:

```bash
git shiplog replay --env prod --deployment "$DEPLOY_ID" --step
```

## Related Code
- `lib/commands.sh` — `cmd_export_json()`

## Tests
- `test/03_export_json_ndjson.bats:11`
