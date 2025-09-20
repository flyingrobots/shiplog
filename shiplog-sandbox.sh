#!/usr/bin/env bash
set -euo pipefail

# shiplog sandbox launcher
# Builds the local Docker image and drops into an interactive shell with the
# current repository mounted at /workspace. Use SHIPLOG_SANDBOX_IMAGE to
# override the image tag.

IMAGE_NAME=${SHIPLOG_SANDBOX_IMAGE:-shiplog-sandbox:latest}
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [ "$#" -eq 0 ]; then
  CONTAINER_CMD=(/bin/bash)
else
  CONTAINER_CMD=("$@")
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ docker CLI not found" >&2
  exit 1
fi

echo "📦 Building $IMAGE_NAME from $ROOT_DIR"
docker build -t "$IMAGE_NAME" "$ROOT_DIR"

RUN_ARGS=(--rm -it -w /workspace -v "$ROOT_DIR:/workspace")

if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ]; then
  RUN_ARGS+=( -e SSH_AUTH_SOCK -v "$SSH_AUTH_SOCK:$SSH_AUTH_SOCK" )
fi

if [ -f "$HOME/.gitconfig" ]; then
  RUN_ARGS+=( -v "$HOME/.gitconfig:/root/.gitconfig:ro" )
fi

echo "🚀 Starting sandbox shell in $IMAGE_NAME"
docker run "${RUN_ARGS[@]}" "$IMAGE_NAME" "${CONTAINER_CMD[@]}"
