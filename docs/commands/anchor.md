# git shiplog anchor

Anchors are durable replay boundaries per environment. They live under `refs/_shiplog/anchors/<env>` and can be pushed/fetched like any other ref. Use them with `git shiplog replay --since-anchor` to page through entries since the last anchor.

## Usage

```bash
git shiplog anchor set  --env prod [--ref <sha>] [--reason "text"]
git shiplog anchor show --env prod [--json]
git shiplog anchor list --env prod
```

## Subcommands

- `set` — Move the env’s anchor to a commit (default: the journal tip for ENV). Writes a reflog entry with your reason.
- `show` — Print the current anchor value. Use `--json` for machine-readable output.
- `list` — Show the anchor’s reflog (the history of moves), including your reasons.

## Why Anchors?

- Portable: Anchors are refs committed to Git; they sync across clones.
- Replay-friendly: `git shiplog replay --since-anchor` replays entries created since the last anchor.
- Audit trail: Each `set` records a reflog entry (tip: keep reflogs around longer via repo config if desired).

## See Also

- `git shiplog replay --since-anchor` — Anchor-aware replay.
- `docs/features/replay.md` — Additional replay examples.

