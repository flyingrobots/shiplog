FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      git bash coreutils grep gawk sed findutils ca-certificates curl bats jq; \
    git config --system init.defaultBranch main; \
    rm -rf /var/lib/apt/lists/*

COPY --link <<'SH' /usr/local/bin/run-tests
#!/usr/bin/env bash
set -euo pipefail
echo "=== Ubuntu 24.04 ==="
. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME"
echo "bash: $(bash --version | head -n1)"
echo "git:  $(git --version)"
echo "coreutils: $(stat --version 2>/dev/null | head -n1 || true)"
cd /work
exec bash ./test.sh
SH
RUN chmod +x /usr/local/bin/run-tests

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/run-tests"]
