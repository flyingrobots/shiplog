# bosun input

Collect a single line of text, optionally with a default value.

```
bosun input [--placeholder TEXT] [--value VALUE] [--json]
```

- `--placeholder` sets the prompt shown when running interactively.
- `--value` (alias `--default`) seeds the input; if the user presses enter, the default is returned.
- `--json` emits `{ "value": "…" }` instead of the raw string.

Examples:

```bash
name=$(bosun input --placeholder "Who is deploying?" --value "$USER")

bosun input --value "v1.2.3" --json <<<'v1.2.4'
#> {"value":"v1.2.4"}
```

Non-interactive mode reads from stdin and falls back to the default value when no data is provided.
