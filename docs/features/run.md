# Run Command

## Summary
`git shiplog run` wraps a shell command, captures its stdout/stderr, and records the execution as a Shiplog journal entry. The command output is saved as a git note, and the structured trailer gains a `run` payload describing the invocation. Use `--dry-run` to preview what would happen without executing the command or writing an entry.

## Usage
```bash
git shiplog run --service deploy --reason "Smoke test" -- env printf hi
git shiplog run --dry-run --service deploy --reason "Smoke test" -- env printf hi
```

- `--service` is required in non-interactive mode (and highly recommended in general).
- Place the command to execute after `--`. All arguments are preserved and logged.
- Successful runs inherit `--status-success` (default `success`); failures use `--status-failure` (default `failed`).

## Behavior
- Captures stdout/stderr to a temporary file. When not in boring mode, output is also streamed to your terminal via `tee`.
- `--dry-run` prints the wrapped command, returns exit code 0, and skips execution, journal writes, and log attachment.
- Sets `SHIPLOG_BORING=1` and `SHIPLOG_ASSUME_YES=1` while calling `git shiplog write` so no prompts fire.
- Populates `SHIPLOG_EXTRA_JSON` with:
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
- Attaches the captured log as a git note under `refs/_shiplog/notes/logs` when the entry is written successfully.
- Returns the wrapped command’s exit code so it can be chained in scripts or CI pipelines.

## Options
- `--dry-run` — Print the command that would execute, then exit without running it or writing a journal entry.
- `--env <name>` — Target journal environment (defaults to `SHIPLOG_ENV` or `prod`).
- `--service <name>` — Service/component; required when prompts are disabled.
- `--reason <text>` — Optional free-form description.
- `--status-success <status>` — Status recorded when the command exits 0. Default `success`.
- `--status-failure <status>` — Status recorded when the command fails. Default `failed`.
- `--ticket <id>`, `--region <r>`, `--cluster <c>`, `--namespace <ns>` — Override standard write metadata.
- When there is no output, log attachment is skipped and `log_attached=false` is recorded in the trailer.

## See Also
- `docs/features/write.md`
- `docs/reference/env.md`
- `docs/notes/codex-feedback-on-shiplog.md`
- `docs/reference/json-schema.md`
