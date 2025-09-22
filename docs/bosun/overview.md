# Bosun Overview

Bosun provides lightweight TUI primitives implemented in pure Bash, designed to work in both interactive shells and non-interactive environments while honoring `NO_COLOR`.

Available commands:

- `bosun confirm` — Prompts for a yes/no response, honouring colors unless `NO_COLOR`/`--no-color` is set. Flags include `--yes` for non-interactive acceptance and `--json` to emit `{"ok": true|false}`. Returns exit 0 on yes, exit 1 on no. Example: `bosun confirm "Deploy?"` → `Deploy? [y/N] y` then `yes`.
- `bosun input` — Reads a single line from the user or stdin with optional `--placeholder`, `--value/--default`, and `--json` flags. Falls back to the provided default when stdin is empty and exits 0 with the captured text. Example: `bosun input --placeholder "Artifact" --value latest` prints `latest` when the user presses enter.
- `bosun choose` — Displays a numbered menu of options supplied as positional arguments. Supports `--header`, `--default`, `--json`, and obeys `NO_COLOR`. Returns the chosen value (or the default in non-TTY mode); `bosun choose --header "Env" dev stage prod` selects an environment.
- `bosun style` — Formats text inside a bordered box; accepts `--title`, `--width`, and `--no-color`. Useful for pretty previews such as `bosun style --title "Preview" -- "Deploying api@v1"`.
- `bosun table` — Renders tab-separated data as fixed-width columns. Requires `--columns` and optional `--rows-file`, `--width`, `--no-color`. Example: `printf 'svc\tstatus\nweb\tready\n' | bosun table --columns "Service,Status"`.
- `bosun spin` — Wraps a command with a spinner while it runs; `--title` configures the message and `--no-color` removes styling. Returns the exit code of the wrapped command, e.g. `bosun spin --title "Running tests" -- make test`.

Use `bosun help <command>` for full details and examples of each helper.
