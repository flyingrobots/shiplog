# Completed Tasks (archived on 2025-09-25)

## Major Completed Items

- Complete policy and sync tooling hardening
```yaml
priority: P1
impact: stabilizes policy resolution and schema validation
steps:
  - finish lib/policy.sh refactor (default signing behaviour, author aggregation)
  - update scripts/shiplog-sync-policy.sh to detect jq --schema cleanly
  - ensure resolve_signers_path and policy parsing align with new trust model
blocked_by: []
notes:
  - cross-validate against docs/TRUST.md examples
  - DONE: per-env require_signed resolution - environments can independently enforce/skip signature validation (implemented in CLI commands and pre-receive hook)
  - DONE: sync-policy writes `.shiplog/policy.json` in the policy ref tree
  - DONE: canonicalize policy writes (jq -S) and treat semantically equal JSON as no-op
  - DONE: robust `policy show --json` path and trailing flag parsing
```

- Refactor installers and uninstallers for path safety
```yaml
priority: P1
impact: avoids destructive rm/git operations on unsafe paths
steps:
  - replace install script path resolution with pure-shell realpath/readlink logic
  - remove embedded interpreters from uninstall script or move them into a standalone helper with validation
  - add regression tests covering FORCE/DATA dir edge cases
blocked_by: []
notes:
  - align logging with README security guidance
  - DONE: installer no longer fetches Shiplog refs into the caller repo; fetch scoped to `$SHIPLOG_HOME` and force-refreshed tool refs
```

- Finish sandboxed test migration and isolation
```yaml
priority: P0
impact: prevents mutations to real remotes and exercises new trust flow
steps:
  - convert remaining tests (02,09,11,13,helpers) to use shiplog-testing-sandbox clone helpers
  - add jq-aware trailer helpers and ensure failures surface clearly
  - guarantee tests create throw-away remotes/repos and restore git config state
blocked_by: []
notes:
  - all bats suites now bootstrap isolated clones; journal JSON assertions use git cat-file helpers
```

- Trailer JSON validation command
```yaml
priority: P2
impact: catches invalid trailers proactively; improves UX and CI checks
steps:
  - add `git shiplog validate-trailer [COMMIT]` (defaults to latest journal)
  - pretty errors; minimal structural checks (env, ts, status, what.service, when.dur_s)
  - document in docs/features; add unit tests for malformed trailers (future)
blocked_by: []
notes:
  - DONE: implemented command using jq; documented in docs/features/validate-trailer.md
```

## New/Updated Tasks (GitHub Toolkit & UX)

- Add `git shiplog show --json` and `--json-compact`
- Honor trailing `--boring` on subcommands
- Add `git shiplog refs root show|set` and `refs migrate` wrapper
- Add migration helper script (`scripts/shiplog-migrate-ref-root.sh`)
- Add importable GitHub Ruleset JSON (branch namespace)
- Add GitHub Actions workflows for verify (branch) and audit (custom refs)
- Document GitHub protections and ref root switching (docs/hosting/github.md, runbook)
- Add Environment Reference (docs/reference/env.md) and README quick commands
