# Export JSON Command

## Summary
`git shiplog export-json` emits NDJSON records for journal entries so downstream systems can ingest Shiplog data. Each line combines the stored JSON trailer with the commit SHA.

## Usage
```bash
git shiplog export-json [ENV] | jq '.'
```

## Behavior
- Requires `jq` version 1.6 or later to be available.
- Streams commits in reverse chronological order and appends a `commit` field to each JSON payload.
- Works with the same environment resolution rules as other commands.

## Related Code
- `lib/commands.sh:132`

## Tests
- `test/03_export_json_ndjson.bats:11`
