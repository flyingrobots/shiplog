# Shiplog VS Code Dev Container
FROM mcr.microsoft.com/devcontainers/base:bookworm

ARG DEBIAN_FRONTEND=noninteractive
ARG GUM_VERSION=0.13.0
ARG YQ_VERSION=4.44.3

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       jq \
       bats \
       gnupg \
       curl \
       shellcheck \
    && rm -rf /var/lib/apt/lists/*

RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in \
         amd64)  gusuf=Linux_x86_64 ;; \
         arm64)  gusuf=Linux_arm64 ;; \
         armhf)  gusuf=Linux_armv6 ;; \
         *) echo "Unsupported arch: $arch" >&2 && exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_${gusuf}.tar.gz" \
         -o /tmp/gum.tgz \
    && tar -C /usr/local/bin -xzf /tmp/gum.tgz gum \
    && rm -f /tmp/gum.tgz \
    && chmod +x /usr/local/bin/gum \
    && gum --version

RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in \
         amd64)  yq_bin=yq_linux_amd64 ;; \
         arm64)  yq_bin=yq_linux_arm64 ;; \
         armhf)  yq_bin=yq_linux_arm ;; \
         *) echo "Unsupported arch for yq: $arch" >&2 && exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/${yq_bin}" \
         -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && yq --version

USER vscode
WORKDIR /workspaces/shiplog
