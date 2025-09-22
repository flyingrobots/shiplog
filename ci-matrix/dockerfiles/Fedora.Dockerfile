FROM fedora:latest

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN set -eux; \
    dnf -y install git bash coreutils grep gawk sed findutils ca-certificates curl bats jq; \
    git config --system init.defaultBranch main; \
    dnf clean all

COPY --link <<'SH' /usr/local/bin/run-tests
#!/usr/bin/env bash
set -euo pipefail
cd /work
bash ./test.sh
SH
RUN chmod +x /usr/local/bin/run-tests

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/run-tests"]
