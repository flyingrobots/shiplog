# bosun style

Render text inside a decorated box for human-friendly output.

```
bosun style [--title TEXT] [--width NUM] [--no-color] -- "content"
```

- `--title` adds a highlighted caption in the top border.
- `--width` sets the overall box width (default 80 characters).
- `--no-color` removes ANSI styling (also implied by `NO_COLOR`).

Examples:

```bash
bosun style --title "Preview" -- "Deploying web@v1.2.3 to prod"

printf 'Multi-line\ncontent\n' | bosun style --width 60
```

The command trims ANSI codes when computing layout so coloured text remains aligned.
