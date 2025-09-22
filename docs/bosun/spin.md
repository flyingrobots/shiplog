# bosun spin

Wrap a command in a simple spinner to show progress.

```
bosun spin [--title TEXT] [--no-color] -- <command> [args...]
```

- `--title` text is displayed next to the spinner while the command runs.
- `--no-color` removes ANSI styling.

The spinner only appears when stdout is a TTY; in pipelines or CI the command executes normally without animation.

Examples:

```bash
bosun spin --title "Deploying" -- sleep 3

bosun spin --title "Running tests" -- make test
```

The exit code of `bosun spin` matches the wrapped command, emitting a green check mark on success and a red cross on failure.
