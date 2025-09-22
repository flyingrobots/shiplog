FROM alpine:3

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN set -eux; \
    apk add --no-cache \
      bash coreutils grep gawk sed findutils git ca-certificates curl jq bats

RUN git config --system init.defaultBranch main

COPY --link <<'SH' /usr/local/bin/run-tests
#!/usr/bin/env bash
set -euo pipefail
echo "=== Alpine 3 (musl/BusyBox) ==="
cat /etc/alpine-release || true
echo "bash: $(bash --version | head -n1)"
echo "git:  $(git --version)"
echo "coreutils: $(stat --version 2>/dev/null | head -n1 || echo busybox-stat)"
cd /work
exec bash ./test.sh
SH
RUN chmod +x /usr/local/bin/run-tests

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/run-tests"]
