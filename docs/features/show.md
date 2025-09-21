# Show Command

## Summary
`git shiplog show` prints the details for a specific shiplog commit entry (or the latest one by default). It separates the human-readable header from the JSON metadata trailer and outputs any attached git notes to stdout.

## Usage
```bash
git shiplog show [COMMIT]
```

## Behavior
- Defaults to the latest commit in the current branch's shiplog history.
- When `gum` is installed, displays output in formatted boxes for better readability.
- When `gum` is unavailable, outputs plain text. If `jq` is available, JSON metadata is pretty-printed.
- Automatically detects and displays any git notes attached under `refs/_shiplog/notes/logs/<commit>`.

## Related Code
- `lib/commands.sh` - `show_command()` function
- `lib/git.sh` - `get_shiplog_entry()` and related git operations

## Tests
- `test/02_write_and_ls_show.bats` - Basic show command functionality
- `test/04_notes_attachment.bats` - Notes detection and display
- `test/08_show_latest_default.bats` - Default behavior when no commit specified
