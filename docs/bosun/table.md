# bosun table

Format tab-separated rows into a padded table.

```
bosun table --columns "Col1,Col2" [--rows-file file.tsv] [--width NUM] [--no-color]
```

- `--columns` (required) defines the column headers.
- `--rows-file` reads rows from a TSV file instead of stdin.
- `--width` controls the horizontal padding (defaults to automatic sizing).
- `--no-color` disables ANSI styling.

Input rows must be tab-separated and match the number of headers.

Examples:

```bash
printf 'abc\tREADY\nxyz\tFAILED\n' | \
  bosun table --columns "Service,Status"

bosun table --columns "Env,Result" --rows-file results.tsv
```

Bosun validates the column count and reports a helpful error when rows are malformed.
