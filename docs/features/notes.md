# Notes Attachments

## Summary
Shiplog can attach NDJSON logs or other artifacts to journal entries using Git notes. By default notes are stored under `refs/_shiplog/notes/logs` (configurable via `NOTES_REF`). The attachments appear in `git shiplog show` output.

## Usage
```bash
SHIPLOG_LOG=path/to/log.ndjson git shiplog write prod
```

## Behavior
- When `SHIPLOG_LOG` points to a readable file, the write flow saves it as a note on the newly created commit using `git notes --ref=$NOTES_REF add`.
- `git shiplog show` streams the note contents in the interactive UI or plain output.
- Notes live under a dedicated ref (`NOTES_REF`) so they can be fetched and pushed alongside journals.

## Related Code
- `lib/git.sh:52`
- `lib/git.sh:178`

## Tests
- `test/04_notes_attachment.bats:20`
