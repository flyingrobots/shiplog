# Shiplog Next Steps

1. Replace `gum` integration with the bundled `scripts/bosun` helper and add Bash fallbacks.
2. Introduce `--non-interactive` / `--assume-yes` flags and supporting `SHIPLOG_NON_INTERACTIVE` env handling.
3. Switch portable time/duration helpers to avoid `date -d` (support macOS).
4. Validate JSON trailer payloads (and make `jq` optional).
5. Simplify policy parsing to a single parser (likely jq-only) and update the pre-receive hook accordingly.
6. Remove the remaining hard gum dependency from tests/Docker stubs.
