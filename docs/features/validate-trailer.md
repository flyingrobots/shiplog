# Validate Trailer

Validate the JSON trailer embedded in a Shiplog entry.

## Usage

```
git shiplog validate-trailer [COMMIT]
```

- When `COMMIT` is omitted, validates the latest entry under the default journal environment (`SHIPLOG_ENV` or `prod`).
- Exits 0 on success; exits non‑zero and prints errors if invalid.
- Requires `jq` (mandatory dependency).

## What It Checks

- JSON is well‑formed and parseable.
- Minimal structural fields and types:
  - `env` (non‑empty string)
  - `ts` (non‑empty string; timestamp)
  - `status` (non‑empty string)
  - `what.service` (non‑empty string)
  - `when.dur_s` (number)

You can use `git shiplog show --json` to print a single entry’s trailer payload for inspection, or `git shiplog export-json` for NDJSON across many entries.

## Examples

```
# Validate latest
git shiplog validate-trailer

# Validate a specific entry
git shiplog validate-trailer refs/_shiplog/journal/prod

# Pretty-print the trailer for manual inspection
git shiplog show --json | jq
```

