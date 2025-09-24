# Shiplog Plugin Hooks (Experimental)

Plugins let you customize Shiplog without patching the core scripts. At the moment we support a single filter stage, `pre-commit-message`, which receives the commit message as plain text on stdin and expects the modified message on stdout. Scripts are executed sequentially in lexicographic order, with each script's output becoming the next script's input. This is useful for scrubbing secrets or appending metadata.

## Directory Layout

Shiplog looks for executable scripts under `.shiplog/plugins/<stage>.d/`. For example:

```bash
.shiplog/
  plugins/
    pre-commit-message.d/
      10-scrub-secrets.sh
      20-add-metadata.sh
```

Each script must be executable and live inside the stage directory. Scripts run in lexicographic order based on filename.

## Script Interface

Scripts receive the stage name as `$1` and the current payload on `stdin`. They must write the transformed payload to `stdout`. If a script exits non-zero, Shiplog aborts the operation.

Example scrubber:

> [!WARNING]
>  This is a trivial example. Real secret detection requires comprehensive patterns for AWS keys, GitHub tokens, API keys, etc.

```bash
#!/usr/bin/env bash
set -euo pipefail
awk '{ gsub(/secret-[A-Za-z0-9]+/, "[REDACTED]"); print }'
```

Place this script at `.shiplog/plugins/pre-commit-message.d/10-scrub.sh`, make it executable (`chmod +x`), and Shiplog will run it before writing the journal entry.

## Safety Notes

- Plugins run with the same privileges as the CLI. Keep scripts under version control and review them like any other code.
- Shiplog ignores scripts outside the declared plugins directory to prevent accidental traversal.
- The plugin system is experimental; more stages (post-write, log attachment, etc.) will arrive as we flesh out the extension framework.

## Custom Plugin Directory

Set `SHIPLOG_PLUGINS_DIR` to override the default `.shiplog/plugins`. This is handy if you need to share a central plugin repository across multiple repos.

```bash
export SHIPLOG_PLUGINS_DIR="$HOME/.config/shiplog/plugins"
```

Shiplog will still look for stage subdirectories inside the custom directory.
