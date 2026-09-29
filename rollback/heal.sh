#!/bin/sh
# Self-healing rollback: redeploy prod carts from the GOOD spec (base compose +
# prod publish override, WITHOUT carts-badbuild.override.yml), which recreates
# the container with no CPU cap. A CPU cap set via --cpus cannot be removed with
# `docker update`, so a recreate is required.
set -u
D="${DTACM_HOME:-/home/abraham_anugrah/dtacm-docker}"
echo "[rollback $(date -u +%H:%M:%S)] redeploying good prod carts from $D"
cd "$D" || { echo "repo $D not found"; exit 1; }
docker compose -p sockshop-prod --env-file compose/prod.env \
  -f compose/docker-compose.sockshop.yml \
  -f compose/docker-compose.prod.override.yml \
  up -d --force-recreate carts-internal 2>&1
echo "[rollback] prod carts redeployed (good build, no throttle)"
