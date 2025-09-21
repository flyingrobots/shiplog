# List Command

## Summary
`git shiplog ls` displays recent journal entries for an environment. It renders a gum-powered table in interactive shells and falls back to tab-separated output in boring mode or when gum is unavailable.

## Usage
```bash
git shiplog ls [ENV]
```

## Behavior
- Defaults to the resolved environment (`--env` flag or `SHIPLOG_ENV`).
- Requires the journal ref to exist; otherwise exits with a helpful error.
- Pulls commit metadata (status, service, author, timestamp) for each entry and feeds it to the UI helper.

## Related Code
- `lib/commands.sh:89`
- `lib/git.sh:141`

## Tests
- `test/01_init_and_empty_ls.bats:25`
- `test/02_write_and_ls_show.bats:31`
