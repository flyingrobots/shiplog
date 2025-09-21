# Init Command

## Summary
`git shiplog init` configures a Git repository to synchronize Shiplog journals and notes by adding remote tracking refspecs for `refs/_shiplog/*` references and enabling comprehensive reflog tracking via `core.logAllRefUpdates` to maintain rollback capability.

## Usage
```bash
git shiplog init
```

## Behavior
- Requires running inside a Git repo with at least one commit.
- Adds fetch/push refspecs for `refs/_shiplog/*` to enable remote synchronization.
- Enables `core.logAllRefUpdates` to maintain comprehensive reflog history.
- Conditionally adds a HEAD push refspec only if no push configuration exists (preserves existing push behavior).
- Produces a human-friendly confirmation in interactive shells and a plain message when `--boring` is supplied.

## Related Code
- `lib/commands.sh:3`
- `lib/git.sh:225`

## Tests
- `test/01_init_and_empty_ls.bats:12`
