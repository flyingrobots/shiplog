# bosun style

Render text inside a decorated ASCII box with borders and optional title styling for human-friendly terminal output.



- `--title` adds a bold, colored caption centered in the top border.
- `--width` sets the overall box width (default 80 characters). Content longer than width will be wrapped.
- `--no-color` removes ANSI styling (also implied by `NO_COLOR`).
Examples:

The command trims ANSI codes when computing layout so coloured text remains aligned.
