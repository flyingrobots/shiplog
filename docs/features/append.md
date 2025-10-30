# Append Command

## Summary
`git shiplog append` records a deployment entry non-interactively by merging a JSON object you supply (from CLI, file, or stdin) into the Shiplog trailer. It runs `write` under the hood in boring/auto-confirm mode, honoring the same metadata flags and policy checks.

## Usage
```bash
# Merge JSON from stdin and set required metadata via flags
printf '{"checks":{"canary":"green"}}' | \
  git shiplog append --service deploy --status success --json -

# Merge from a file and stamp a Deployment ID
git shiplog append --service web --status success \
  --json-file payload.json --deployment REL-2025-10-30.1
```

## Flags and Behavior
- Accepts the same context flags as `write` (`--service`, `--status`, `--reason`, `--ticket`, `--region`, `--cluster`, `--namespace`, `--image`, `--tag`, `--run-url`, `--log`/`--attach`, `--env`).
- `--json` or `--json-file` must supply a JSON object; it is merged at the top level of the trailer.
- `--deployment <id>` (or `SHIPLOG_DEPLOY_ID`) adds `deployment.id = "<id>"`. If `--ticket` is omitted, the ID is mirrored to `why.ticket` for compatibility.
- `--log PATH` (alias `--attach PATH`) attaches an NDJSON note.
- `--dry-run` previews without writing.

## Examples
```bash
# Attach a run URL and canary result
git shiplog append --service api --status success \
  --run-url https://ci.example/run/42 \
  --json '{"checks":{"canary":"green"}}'

# Append with a Deployment ID and a ticket
git shiplog append --service api --status in_progress \
  --ticket OPS-4242 --deployment REL-2025-10-30.1 \
  --json '{"stage":"migrate"}'
```

## See Also
- `docs/features/write.md`
- `docs/features/run.md`
- `docs/features/command-reference.md`
- `docs/features/replay.md`
