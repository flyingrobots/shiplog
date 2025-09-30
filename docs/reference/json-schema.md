# Shiplog Entry JSON Schema

This document captures the layout of the JSON trailer that `git shiplog` writes for journal entries. The schema is intentionally descriptive rather than a strict validator, but it matches what `compose_message` emits today.

## Top-Level Structure

```json
{
  "version": 1,
  "env": "prod",
  "ts": "2025-09-30T01:23:45Z",
  "who": {
    "name": "Shiplog Tester",
    "email": "shiplog-tester@example.com"
  },
  "what": {
    "service": "api",
    "artifact": "ghcr.io/example/api:2025-09-30.1",
    "repo_head": "0f4e7890..."
  },
  "where": {
    "env": "prod",
    "region": "us-west-2",
    "cluster": "prod-a",
    "namespace": "prod"
  },
  "why": {
    "reason": "post-release smoke",
    "ticket": "OPS-1234"
  },
  "how": {
    "pipeline": null,
    "run_url": "https://ci.example/run/42"
  },
  "status": "success",
  "when": {
    "start_ts": "2025-09-30T01:22:12Z",
    "end_ts": "2025-09-30T01:23:45Z",
    "dur_s": 93
  },
  "seq": 17,
  "journal_parent": "0d135ab...",
  "trust_oid": "63c2d9c...",
  "previous_anchor": null,
  "repo_head": "0f4e7890...",
  "run": {
    "argv": ["env", "printf", "hi"],
    "cmd": "env printf hi",
    "exit_code": 0,
    "status": "success",
    "duration_s": 1,
    "started_at": "2025-09-30T01:22:12Z",
    "finished_at": "2025-09-30T01:22:13Z",
    "log_attached": true
  }
}
```

### Field Notes

- `version` — Reserved for schema evolution (currently `1`).
- `env` — Journal scope (e.g., `prod`). Mirrors the command’s environment target.
- `ts` — Timestamp when the entry was written (`fmt_ts`, UTC ISO-8601).
- `who` — Author identity captured from Git config or overrides.
- `what.service` — Required service/component name.
- `what.artifact` — Artifact identifier (image+tag) when supplied.
- `what.repo_head` — Commit hash of the repository HEAD when the entry was recorded.
- `where` — Deployment target metadata; `namespace` defaults to the journal name if omitted.
- `why` — Reason text and optional ticket identifier.
- `how.run_url` — CI/CD execution URL when provided.
- `status` — One of `success`, `failed`, `in_progress`, `skipped`, `override`, `revert`, `finalize`.
- `when.dur_s` — Duration in whole seconds between `start_ts` and `end_ts`.
- `seq` — Monotonic counter within the journal.
- `journal_parent` — SHA of the previous journal entry (or `null` for genesis).
- `trust_oid` — SHA of the trust ref commit used while writing.
- `previous_anchor` — SHA of the anchor ref before the write (for anchor workflows).
- `run` — Present when `git shiplog run` populates structured command metadata (see below).
- Any additional objects merged via `SHIPLOG_EXTRA_JSON` (e.g., from `git shiplog append`) are placed at the top level alongside these keys.

### `run` Object

The `run` block appears when the entry was produced by `git shiplog run`. Its shape is:

| Field | Type | Description |
|-------|------|-------------|
| `argv` | array[string] | Original argument vector passed to the wrapped command. |
| `cmd` | string | Shell-quoted command string for human readability. |
| `exit_code` | integer | Exit status of the wrapped command. |
| `status` | string | Final status (`success` or `failed` as recorded in the trailer; CLI flags map to these values). |
| `duration_s` | integer | Execution duration in seconds. |
| `started_at` | string | UTC timestamp when execution began. |
| `finished_at` | string | UTC timestamp when execution completed. |
| `log_attached` | boolean | `true` when a log note was attached, `false` when output was empty. |

### JSON Schema (Draft 2020-12 excerpt)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://shiplog.dev/schema/journal-entry.json",
  "type": "object",
  "required": ["version", "env", "ts", "who", "what", "where", "status", "when", "seq", "trust_oid", "repo_head"],
  "properties": {
    "version": {"type": "integer", "const": 1},
    "env": {"type": "string"},
    "ts": {"type": "string", "format": "date-time"},
    "who": {
      "type": "object",
      "required": ["name", "email"],
      "properties": {
        "name": {"type": "string"},
        "email": {"type": "string", "format": "email"}
      }
    },
    "what": {
      "type": "object",
      "required": ["service", "repo_head"],
      "properties": {
        "service": {"type": "string"},
        "artifact": {"type": ["string", "null"]},
        "repo_head": {"type": "string"}
      }
    },
    "where": {
      "type": "object",
      "required": ["env"],
      "properties": {
        "env": {"type": "string"},
        "region": {"type": ["string", "null"]},
        "cluster": {"type": ["string", "null"]},
        "namespace": {"type": ["string", "null"]}
      }
    },
    "why": {
      "type": "object",
      "properties": {
        "reason": {"type": ["string", "null"]},
        "ticket": {"type": ["string", "null"]}
      }
    },
    "how": {
      "type": "object",
      "properties": {
        "pipeline": {},
        "run_url": {"type": ["string", "null"]}
      }
    },
    "status": {
      "type": "string",
      "enum": ["success", "failed", "in_progress", "skipped", "override", "revert", "finalize"]
    },
    "when": {
      "type": "object",
      "required": ["start_ts", "end_ts", "dur_s"],
      "properties": {
        "start_ts": {"type": "string", "format": "date-time"},
        "end_ts": {"type": "string", "format": "date-time"},
        "dur_s": {"type": "integer"}
      }
    },
    "seq": {"type": "integer", "minimum": 0},
    "journal_parent": {"type": ["string", "null"]},
    "trust_oid": {"type": "string"},
    "previous_anchor": {"type": ["string", "null"]},
    "repo_head": {"type": "string"},
    "run": {
      "type": "object",
      "required": ["argv", "cmd", "exit_code", "status", "duration_s", "started_at", "finished_at", "log_attached"],
      "properties": {
        "argv": {
          "type": "array",
          "items": {"type": "string"}
        },
        "cmd": {"type": "string"},
        "exit_code": {"type": "integer"},
        "status": {
          "type": "string",
          "enum": ["success", "failed"]
        },
        "duration_s": {"type": "integer"},
        "started_at": {"type": "string", "format": "date-time"},
        "finished_at": {"type": "string", "format": "date-time"},
        "log_attached": {"type": "boolean"}
      }
    }
  },
  "additionalProperties": true
}
```

## Related Commands

- `git shiplog write`
- `git shiplog run`
- `git shiplog append`

These commands all use the same base schema. `run` populates the `run` object automatically, while `append` merges arbitrary JSON via `SHIPLOG_EXTRA_JSON`.
