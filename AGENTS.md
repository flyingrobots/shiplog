# Git Workflow Guidelines

## Quick Reminders
- Never push directly to main; create a branch and open a PR instead.
- Never amend commits or force-push without explicit user approval; prefer new commits and merges.
- If a task appears to require a force push, stop and ask the user before proceeding.

## Branch Management
- Never push directly to `main`. Create a feature branch from `main` and open a pull request for review.

## Commit History
- Never amend commits or force-push to shared branches without explicit user approval.
- For local branches, prefer `git commit --amend` for fixing recent commits.
- For shared branches, add new commits and use merge commits to preserve history.

## Force Push Policy
- If a task requires force-pushing to a shared branch, stop and request explicit user approval before proceeding.
- Always use `git push --force-with-lease` instead of `git push --force` to prevent overwriting others' work.
