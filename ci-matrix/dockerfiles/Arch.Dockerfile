FROM archlinux:base

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN set -eux; \
    pacman -Sy --noconfirm git bash coreutils grep gawk sed findutils ca-certificates curl jq bats; \
    git config --system init.defaultBranch main; \
    pacman -Scc --noconfirm

COPY --link <<'SH' /usr/local/bin/run-tests
#!/usr/bin/env bash
set -euo pipefail
cd /work
bash ./test.sh
SH
RUN chmod +x /usr/local/bin/run-tests

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/run-tests"]
