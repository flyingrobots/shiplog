# Changelog

## [0.2.0] – 2025-09-30
**Codename:** The Cut of Your Jib

- Added `git shiplog run` to wrap commands, capture logs, and record structured run metadata.
- Added `git shiplog append` for non-interactive entries via `--json` / `--json-file` (stdin supported).
- Added `git shiplog trust show` (table and `--json`) including signer inventory.
- Documented the structured entry schema (`docs/reference/json-schema.md`).
- Defaulted the namespace to the journal name when `SHIPLOG_NAMESPACE` is unset.

## [0.1.0] – 2025-09-26
- Initial tagged release.
