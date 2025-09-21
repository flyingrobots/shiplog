# Verify Command

## Summary
`git shiplog verify` walks a journal and confirms each entry meets the configured signing and allowlist requirements. It surfaces counts for valid entries, bad signatures, and unauthorized authors.

## Usage
```bash
git shiplog verify [ENV]
```

## Behavior
- Resolves policy inputs from the policy ref, working tree, git config, and environment variables.
- Uses `git verify-commit` (with `GIT_SSH_ALLOWED_SIGNERS` when provided) to check signatures when required.
- Fails fast on unauthorized authors or missing signatures and summarizes the results for humans or gum.

## Related Code
- `lib/commands.sh:107`
- `lib/git.sh:58`
- `lib/policy.sh:105`

## Tests
- `test/05_verify_authors.bats:22`
- `test/05_verify_authors.bats:28`
- `test/06_verify_signatures_signed_build.bats:18`
