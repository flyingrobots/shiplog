# Policy Resolution

## Summary
Shiplog resolves policy inputs from multiple sources so teams can manage allowlists and signing requirements declaratively. The `git shiplog policy` command surfaces the effective configuration for debugging.

## Usage
```bash
git shiplog policy [show|validate] [--boring]
```

## Behavior
- Reads `.shiplog/policy.json`, the configured policy ref (`refs/_shiplog/policy/current` by default), git config overrides, and environment variables.
- Produces an interactive table (or plain output with `--boring`) highlighting the source, author list, signer file, and notes ref.
- Supports validation workflows for CI/CD via the `validate` subcommand.

## Related Code
- `lib/policy.sh:3`
- `lib/commands.sh:142`

## Tests
- `test/09_policy_resolution.bats:25`
