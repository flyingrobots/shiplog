# Run Command

## Summary
`git shiplog run` wraps a shell command, captures its stdout/stderr, and records the execution as a Shiplog journal entry. Output is saved as a git note, and the structured trailer gains a `run` payload describing the invocation. Use `--dry-run` to preview the command, status, and trailer fields without executing the command or mutating the journal.

## Usage
```bash
# Standard execution (writes to the journal once the wrapped command runs)
git shiplog run --service deploy --reason "Smoke test" -- env printf hi

# Dry run: rehearse the invocation without executing or writing an entry
git shiplog run --dry-run --service deploy --reason "Smoke test" -- env printf hi
```

- `--service` is required in non-interactive mode (and strongly recommended for clarity).
- Place the command to execute after `--`; all arguments are preserved and logged.
- Successful executions inherit `--status-success` (default `success`); failures use `--status-failure` (default `failed`).

## Dry Run Mode (`--dry-run`)
- Prints a Bosun-formatted preview (or a plain message when Bosun/TTY styling is unavailable) showing the command that would execute.
- Skips command execution, journal entry creation, and log attachment entirely.
- Exits with status `0` when the dry-run invocation is well formed. Invalid flags, missing `--`, or unknown subcommands surface the same non-zero exit codes as the standard command.
- Deterministic output keeps automation safe while rehearsing deploy playbooks.

## Behavior (Standard Runs)
- Captures stdout/stderr to a temporary file. When Bosun is available, output streams through a live preview while still being recorded for notes.
- Sets `SHIPLOG_BORING=1` and `SHIPLOG_ASSUME_YES=1` while delegating to `git shiplog write`, ensuring prompts are bypassed.
- Populates `SHIPLOG_EXTRA_JSON` with a `run` block such as:
  ```json
  {
    "run": {
      "argv": ["env", "printf", "hi"],
      "cmd": "env printf hi",
      "exit_code": 0,
      "status": "success",
      "duration_s": 1,
      "started_at": "2025-09-30T00:00:00Z",
      "finished_at": "2025-09-30T00:00:01Z",
      "log_attached": true
    }
  }
  ```
- Attaches the captured log as a git note under `refs/_shiplog/notes/logs` when an entry is written successfully.
- Returns the wrapped command’s exit code so it can chain cleanly in scripts or CI pipelines.

## Exit Codes
- Dry run
  - `0` when the preview succeeds.
  - Non-zero for malformed invocations or validation errors.
- Standard run
  - Mirrors the wrapped command’s exit status after the journal entry is recorded.
  - Propagates Shiplog errors directly if the CLI fails before wrapping the command.

## Options
- `--dry-run` — Preview the command and metadata without executing or writing an entry.
- `--env <name>` — Target journal environment (defaults to `SHIPLOG_ENV` or `prod`).
- `--service <name>` — Service/component; required when prompts are disabled.
- `--reason <text>` — Optional free-form description.
- `--status-success <status>` — Status recorded when the wrapped command exits 0. Default `success`.
- `--status-failure <status>` — Status recorded when the command fails. Default `failed`.
- `--ticket <id>`, `--region <r>`, `--cluster <c>`, `--namespace <ns>` — Override standard write metadata.
- When there is no output, log attachment is skipped and `log_attached=false` is recorded in the trailer.

## Caveats
- Dry runs do not validate connectivity to downstream systems—it only checks CLI argument parsing and policy prerequisites.
- Ensure `perl` is available if you rely on Bosun rendering; otherwise Shiplog falls back to plain text.

## See Also
- `docs/features/write.md`
- `docs/features/command-reference.md`
- `docs/reference/env.md`
- `docs/notes/codex-feedback-on-shiplog.md`
- `docs/reference/json-schema.md`
