# Changelog

## [0.2.0] – 2025-09-30

**Codename:** The Cut of Your Jib

- Added `git shiplog run` to wrap commands, capture output, and record structured `run` metadata.
- Added `git shiplog append` for non-interactive JSON entries (stdin and file support).
- Added `git shiplog trust show` (table/`--json`), including signer inventory.
- Documented structured trailer schema at `docs/reference/json-schema.md`.
- Defaulted namespace to the journal name when `SHIPLOG_NAMESPACE` is unset.

## [0.1.0] – 2025-09-26

- Initial tagged release (see `docs/releases/v0.1.0.md` for details, if available).
