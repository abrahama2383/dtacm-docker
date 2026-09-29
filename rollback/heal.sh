#!/bin/sh
# Self-healing rollback action. The "bad build" differs from the good build only
# by the CPU cap that carts-badbuild.override.yml puts on prod carts, so healing
# = remove that cap and restart. (For an image-based bad build, replace this with
# a compose redeploy of the previous good revision.)
set -u
C="${CARTS_CONTAINER:-sockshop-prod-carts-internal-1}"
echo "[rollback $(date -u +%H:%M:%S)] healing $C"
docker update --cpu-quota=-1 --cpu-period=100000 "$C" 2>&1 || echo "update failed"
docker restart "$C" >/dev/null 2>&1 || echo "restart failed"
echo "[rollback] prod carts cpu-quota removed + restarted"
