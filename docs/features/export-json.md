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

## Related Code
- `lib/commands.sh` — `cmd_export_json()`

## Tests
- `test/03_export_json_ndjson.bats:11`
