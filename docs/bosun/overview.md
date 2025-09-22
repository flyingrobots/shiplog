# Bosun Overview

Bosun provides lightweight TUI primitives implemented in pure Bash. Each subcommand mirrors the behavior of its `gum` equivalent but works in non-interactive environments and honors `NO_COLOR`.

Available commands:

- `bosun confirm` – ask the user to confirm a prompt.
- `bosun input` – read a value with an optional default.
- `bosun choose` – present a numbered menu and return the selected option.
- `bosun style` – render text inside a decorative box.
- `bosun table` – lay out rows and columns with fixed-width formatting.
- `bosun spin` – wrap a command with a simple spinner.

Use `bosun help <command>` for full details and examples of each helper.
