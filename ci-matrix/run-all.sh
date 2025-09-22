#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

docker compose build

for svc in debian ubuntu fedora alpine arch; do
  echo "==== RUN ${svc^^} ===="
  docker compose run --rm "$svc"
  echo
done
