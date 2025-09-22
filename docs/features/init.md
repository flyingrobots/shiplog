# Init Command

## Summary
`git shiplog init` configures a Git repository to synchronize Shiplog journals and notes by adding remote tracking refspecs for `refs/_shiplog/*` references and enabling comprehensive reflog tracking via `core.logAllRefUpdates` to maintain rollback capability.

## Prerequisites
- Run from the root of a Git repository with at least one commit.
- A remote named `origin` is recommended so Shiplog journals can sync automatically.

## Usage
```bash
git shiplog init
```

This command configures the repository so Shiplog can mirror entries across remotes.

## Examples

### First-time setup
```
$ git shiplog init
Configured refspecs for refs/_shiplog/* and enabled reflogs.
```

### Re-running after initial setup (idempotent)
```
$ git shiplog init
Configured refspecs for refs/_shiplog/* and enabled reflogs.
```

### Outside a repository
```
$ git shiplog init
shiplog: Run inside a git repo.
```

## Behavior
- Adds fetch/push refspecs for `refs/_shiplog/*` to enable remote synchronization.
- Enables `core.logAllRefUpdates`, which tells Git to record a reflog entry for every ref update (branches, tags, `HEAD`, and custom refs) so prior object IDs remain discoverable via `git reflog` or `git reset --reflog`. This improves recovery from mistakes and supports safe rollbacks at the cost of slightly larger reflog history; enable it whenever you need reliable rollback and auditing.
- Adds a `push = HEAD` refspec only if no push configuration exists, preserving custom push setups.
- Produces a human-friendly confirmation in interactive shells and plain output when `--boring` is supplied.

## Related Code
- `lib/commands.sh:3`
- `lib/git.sh:225`

## Tests
- `test/01_init_and_empty_ls.bats:12`
