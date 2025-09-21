# Show Command

## Summary
`git shiplog show` prints the details for a specific journal entry (or the latest one by default). It separates the human header from the JSON trailer and streams any attached notes.

## Usage
```bash
git shiplog show [COMMIT]
```

## Behavior
- Defaults to the head of the current environment's journal.
- Uses gum boxes when available; otherwise emits plain text and optionally pretty-prints the JSON via `jq`.
- Detects and prints `git notes` stored under `refs/_shiplog/notes/logs`.

## Related Code
- `lib/commands.sh:98`
- `lib/git.sh:178`

## Tests
- `test/02_write_and_ls_show.bats:39`
- `test/04_notes_attachment.bats:28`
- `test/08_show_latest_default.bats:14`
