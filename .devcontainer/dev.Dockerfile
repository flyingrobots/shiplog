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

RUN ARCH=$(uname -m) \
    && case "$ARCH" in \
         x86_64)  GUSUF=Linux_x86_64 ;; \
         aarch64) GUSUF=Linux_arm64 ;; \
         armv7l|armv6l) GUSUF=Linux_armv6 ;; \
         *) echo "Unsupported architecture: $ARCH" >&2 && exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_${GUSUF}.tar.gz" \
         -o /tmp/gum.tgz \
    && tar -C /usr/local/bin -xzf /tmp/gum.tgz gum \
    && rm -f /tmp/gum.tgz \
    && chmod +x /usr/local/bin/gum \
    && gum --version

RUN ARCH=$(uname -m) \
    && case "$ARCH" in \
         x86_64)  YQ_BIN=yq_linux_amd64 ;; \
         aarch64) YQ_BIN=yq_linux_arm64 ;; \
         armv7l|armv6l) YQ_BIN=yq_linux_arm ;; \
         *) echo "Unsupported architecture for yq: $ARCH" >&2 && exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/${YQ_BIN}" \
         -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && yq --version

USER vscode
WORKDIR /workspaces/shiplog
