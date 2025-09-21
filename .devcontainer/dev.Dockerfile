# Shiplog VS Code Dev Container
FROM mcr.microsoft.com/devcontainers/base:bookworm

ARG DEBIAN_FRONTEND=noninteractive
ARG GUM_VERSION=0.13.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       jq \
       bats \
       gnupg \
       curl \
       ca-certificates \
       shellcheck \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 scripts/verified-download.sh /usr/local/bin/shiplog-download

RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in \
         amd64)  gum_platform=Linux_x86_64 ;; \
         arm64)  gum_platform=Linux_arm64 ;; \
         armhf)  gum_platform=Linux_armv6 ;; \
         *) echo "Unsupported arch: $arch" >&2 && exit 1 ;; \
       esac \
    && gum_release="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}" \
    && shiplog-download simple "$gum_release" "gum_${GUM_VERSION}_${gum_platform}.tar.gz" "checksums.txt" /tmp/gum.tgz \
    && gum_release="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}" \
    && shiplog-download simple "$gum_release" "gum_${GUM_VERSION}_${gusuf}.tar.gz" "checksums.txt" /tmp/gum.tgz \
    && tar -C /usr/local/bin -xzf /tmp/gum.tgz gum \
    && rm -f /tmp/gum.tgz \
    && chmod +x /usr/local/bin/gum \
    && gum --version

USER vscode
WORKDIR /workspaces/shiplog

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD sh -c 'gum --version && jq --version'
