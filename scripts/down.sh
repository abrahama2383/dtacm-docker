#!/usr/bin/env bash
# Tear down the core stack. Pass -v to also delete data volumes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VFLAG=""
[ "${1:-}" = "-v" ] && VFLAG="-v"

docker compose -f jenkins/docker-compose.jenkins.yml down $VFLAG || true
docker compose -p sockshop-prod \
  -f compose/docker-compose.sockshop.yml \
  -f compose/docker-compose.prod.override.yml down $VFLAG || true
docker compose -p sockshop-dev \
  -f compose/docker-compose.sockshop.yml down $VFLAG || true

echo ">> core stack down. (AWX: cd /var/lib/awx/awxcompose && docker compose down)"
