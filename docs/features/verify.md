# Verify Command

## Summary
`git shiplog verify` validates entries in the shiplog journal (git commit history) against configured signing policies and author allowlists. It reports counts of valid entries, commits with bad signatures, and commits from unauthorized authors.

## Usage
```bash
git shiplog verify [ENV]
```

### Parameters
- `ENV` (optional): journal environment to verify (for example `prod`, `staging`, `dev`). When omitted, the command uses the resolved default environment (`SHIPLOG_ENV` or `prod`).

## Behavior
- Resolves policy inputs from multiple sources in order of precedence: environment variables, git config, working tree, then policy ref (git reference containing policy configuration).
- Uses `git verify-commit` (with `GIT_SSH_ALLOWED_SIGNERS` when provided) to check signatures when required.
- Exits immediately (code 1) when encountering unauthorized authors or missing required signatures, otherwise provides a summary report suitable for human reading or machine parsing.

## Related Code
- `lib/commands.sh` - Main verify command implementation
- `lib/git.sh` - Git signature verification utilities
- `lib/policy.sh` - Policy resolution and validation logic

## Tests
- `test/05_verify_authors.bats:22`
- `test/05_verify_authors.bats:28`
- `test/06_verify_signatures_signed_build.bats:18`
