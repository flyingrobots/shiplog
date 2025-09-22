# bosun confirm

Interactive confirmation prompts for Bosun CLI operations.

Prompt the user for a yes/no response with configurable output formats.

```
bosun confirm [--yes] [--json] [--no-color] "Prompt"
```

- `--yes` automatically answers yes and exits with code 0 (useful for non-interactive scripts).
- `--json` emits `{"ok":true}` or `{"ok":false}` instead of plain `yes`/`no` text.
- `--no-color` disables ANSI styling (also honored when `NO_COLOR` environment variable is set).

Examples:

```bash
bosun confirm "Deploy to production?"
#> yes | no

bosun confirm --yes "Skip safety check"
# exits 0 without prompting

bosun confirm --json "Continue?"
#> {"ok":true}
```
