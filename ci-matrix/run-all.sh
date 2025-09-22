#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-shiplog-ci}"

cleanup() {
  docker compose down --remove-orphans --volumes >/dev/null 2>&1 || true
}

cleanup
trap cleanup EXIT

docker compose build

for svc in debian ubuntu fedora alpine arch; do
  echo "==== RUN ${svc^^} ===="
  docker compose run --rm "$svc"
  echo
done
