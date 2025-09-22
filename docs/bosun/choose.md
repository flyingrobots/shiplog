# bosun choose

Display a numbered menu and return the selected option.

```
bosun choose [--header TEXT] [--default OPTION] [--json] OPTION...
```

- `--header` prints a heading above the menu.
- `--default` specifies the fallback option for non-interactive runs.
- `--json` emits `{ "value": "…" }` instead of the raw choice.

Examples:

```bash
env=$(bosun choose --header "Select environment" dev stage prod)

bosun choose --default stage --json dev stage prod <<<''
#> {"value":"stage"}
```

When running without a TTY the command picks the default option (or the first value if no default is given).
