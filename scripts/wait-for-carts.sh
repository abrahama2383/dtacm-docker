#!/usr/bin/env bash
# Wait until the carts service on a given SockShop network answers its health check.
# Usage: wait-for-carts.sh <network-name>   e.g. sockshop-dev_net
set -euo pipefail
NET="${1:?usage: wait-for-carts.sh <docker-network>}"
TIMEOUT="${2:-300}"   # seconds
INTERVAL=10
elapsed=0

echo "Waiting up to ${TIMEOUT}s for carts health on network ${NET}..."
while [ "$elapsed" -lt "$TIMEOUT" ]; do
  # curl the carts health endpoint from a throwaway container on the same network
  if docker run --rm --network "$NET" curlimages/curl:8.7.1 \
        -sf -m 5 "http://carts/carts/1/items/health" >/dev/null 2>&1; then
    echo "carts is healthy."
    exit 0
  fi
  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
  echo "  ...still waiting (${elapsed}s)"
done

echo "carts did not become healthy within ${TIMEOUT}s (continuing anyway)."
# non-fatal: the demo can still proceed / Dynatrace will detect the problem
exit 0
