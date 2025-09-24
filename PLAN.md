# Shiplog Next Steps

## Priority 1 (Critical)

1. **Adopt Bosun integration** with bundled `scripts/bosun` helper
   - Add Bash fallbacks for all interactive components
   - Acceptance: All interactive calls use Bosun, zero external UI dependencies

2. **Add non-interactive mode support**
   - Implement `--non-interactive` and `--assume-yes` flags
   - Support `SHIPLOG_NON_INTERACTIVE=1` env var (defaults to --assume-yes behavior)
   - Acceptance: CI/automated environments work without user prompts

## Priority 2 (High)  

3. **Fix macOS compatibility in time helpers**
   - Replace `date -d` usage with portable alternatives
   - Acceptance: All time/duration operations work on macOS and Linux

4. **Add JSON trailer validation**
   - Validate JSON payloads in trailers
   - Make jq dependency optional with graceful degradation
   - Acceptance: Invalid JSON is caught early, jq absence doesn't break basic functionality

5. **Migrate policy parsing to jq-only**
   - Remove yq dependency entirely (migrate from yq as planned)
   - Update pre-receive hook to use single jq parser
   - Acceptance: All policy parsing works with jq, yq completely removed

## Priority 3 (Medium)

6. **Clean up test dependencies**
   - Remove remaining hard UI dependencies from test/Docker stubs
   - Acceptance: Tests run without external prompt tooling installed
7. **Add policy toggle helper**
   - Implement `git shiplog policy require-signed <true|false>` and `git shiplog policy toggle`
   - Update `.shiplog/policy.json` and sync `refs/_shiplog/policy/current` (no signing by default)
   - Acceptance: One-liners exist to switch unsigned ↔ signed and publish
