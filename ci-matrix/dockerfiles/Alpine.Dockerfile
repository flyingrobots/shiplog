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
cd /work
bash ./test.sh
SH
RUN chmod +x /usr/local/bin/run-tests

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/run-tests"]
