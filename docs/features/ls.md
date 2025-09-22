# git shiplog ls - List Journal Entries

## Summary
`git shiplog ls` displays recent journal entries for an environment. In interactive shells, it renders entries in a formatted table using the gum CLI tool. When gum is unavailable or when running in non-interactive mode, it outputs tab-separated values instead.

## Usage
```bash
git shiplog ls [ENV]
```

## Parameters
- `ENV` *(optional)* — target environment name. When omitted, Shiplog resolves the environment in this order: command argument, `--env` flag, `SHIPLOG_ENV`, and finally the tool’s default environment.

## Examples
```bash
# List entries for the default environment
git shiplog ls

# List entries for production explicitly
git shiplog ls production

# List entries for staging using the --env flag
git shiplog --env staging ls
```

## Behavior
- **Environment Resolution**: Uses environment specified by:
  1. Command line argument `[ENV]`
  2. `--env` flag
  3. `SHIPLOG_ENV` environment variable
  4. Falls back to default if none specified
- **Journal Validation**: Requires the journal reference (`refs/shiplog/<env>`) to exist. If missing, exits with error: "No journal found for environment '<env>'. Run 'git shiplog init <env>' first."
- **Entry Processing**: Extracts the following metadata from each journal commit:
  - Status (deployed/failed/etc.)
  - Service name
  - Author information
  - Timestamp
- **Output**: Passes extracted data to UI rendering system

## Related Code
- `lib/commands.sh` - Main command implementation
- `lib/git.sh` - Git journal operations and metadata extraction

## Tests
- `test/01_init_and_empty_ls.bats:25`
- `test/02_write_and_ls_show.bats:31`
