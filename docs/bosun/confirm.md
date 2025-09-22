# bosun confirm

Prompt the user for a yes/no response.

```
bosun confirm [--yes] [--json] [--no-color] "Prompt"
```

- `--yes` automatically answers yes (useful for non-interactive scripts).
- `--json` emits `{ "ok": true|false }` instead of plain `yes`/`no`.
- `--no-color` disables ANSI styling (also honoured when `NO_COLOR` is set).

Examples:

```bash
bosun confirm "Deploy to production?"
#> yes | no

bosun confirm --yes "Skip safety check"
# exits 0 without prompting

bosun confirm --json "Continue?"
#> {"ok":true}
```
