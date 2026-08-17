#!/usr/bin/env bash
# Bring up the core stack: shared network + SockShop dev & prod + Jenkins.
# (AWX is installed separately via awx/install-awx.sh - it's heavier.)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[ -f .env ] || { echo "Create .env first: cp .env.example .env && edit it"; exit 1; }
set -a && . ./.env && set +a

echo ">> creating shared 'dtacm' network (if missing)"
docker network inspect dtacm >/dev/null 2>&1 || docker network create dtacm

echo ">> building glibc carts image (dtacm/carts:1.0) if missing"
docker image inspect dtacm/carts:1.0 >/dev/null 2>&1 || docker build -t dtacm/carts:1.0 carts-glibc

echo ">> SockShop DEV (staging)"
docker compose -p sockshop-dev --env-file compose/dev.env \
  -f compose/docker-compose.sockshop.yml up -d --remove-orphans

echo ">> SockShop PRODUCTION (+carts published on :${CARTS_PUBLISH_PORT:-8091})"
docker compose -p sockshop-prod --env-file compose/prod.env \
  -f compose/docker-compose.sockshop.yml \
  -f compose/docker-compose.prod.override.yml up -d --remove-orphans

echo ">> Jenkins"
docker compose -f jenkins/docker-compose.jenkins.yml up -d --build

cat <<EOF

Up.
  SockShop dev  UI : http://localhost:8079
  SockShop prod UI : http://localhost:8081
  Jenkins          : http://localhost:8080   (admin / see .env)
  AWX (if installed): http://localhost:8052   (admin / dynatrace)
EOF
