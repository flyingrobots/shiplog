# Write Command

## Summary
`git shiplog write` records a deployment entry as a signed empty-tree commit under `refs/_shiplog/journal/<env>`. It gathers metadata via prompts (or environment variables in boring mode) and enforces policy allowlists before appending.

## Usage
```bash
git shiplog write [ENV]
# non-interactive
SHIPLOG_BORING=1 git shiplog --yes write prod
```

## Behavior
- Validates the author against the resolved allowlist and performs a signing precheck when signatures are required.
- Prompts for service, status, change details, and artifact information; respects `SHIPLOG_*` env overrides.
- Generates both a human-readable header and a JSON trailer; optionally attaches NDJSON logs via `SHIPLOG_LOG`.
- Accepts `--yes` to skip confirmation prompts (sets `SHIPLOG_ASSUME_YES=1`).
- Fast-forwards the journal ref; aborts if the ref is missing or would require a force update.
- Automatically pushes the updated journal (and attached notes) to `origin` when available; disable with `SHIPLOG_AUTO_PUSH=0` or `--no-push`.

## Related Code
- `lib/commands.sh:15`
- `lib/git.sh:52`
- `lib/common.sh:20`

## Tests
- `test/02_write_and_ls_show.bats:22`
- `test/05_verify_authors.bats:9`
- `test/10_boring_mode.bats:31`
