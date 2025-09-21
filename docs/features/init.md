# Init Command

## Summary
`git shiplog init` bootstraps a repo so Shiplog journals and notes sync like any other ref. It adds the hidden refspecs for `_shiplog/*` and enables reflogs so rollbacks remain detectable.

## Usage
```bash
git shiplog init
```

## Behavior
- Requires running inside a Git repo with at least one commit.
- Adds fetch/push refspecs for `refs/_shiplog/*` and turns on `core.logAllRefUpdates`.
- Produces a human-friendly confirmation in interactive shells and a plain message when `--boring` is supplied.

## Related Code
- `lib/commands.sh:3`
- `lib/git.sh:225`

## Tests
- `test/01_init_and_empty_ls.bats:12`
