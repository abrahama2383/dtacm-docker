#!/usr/bin/env bash
# Quick health view of every workshop component.
set -euo pipefail
echo "=== Containers ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' \
  | grep -E 'NAMES|sockshop-|dtacm-jenkins|awx_' || true
echo ""
echo "=== Endpoints ==="
for name in "dev UI|http://localhost:8079" "prod UI|http://localhost:8081" \
            "Jenkins|http://localhost:8080/login" "AWX|http://localhost:8052"; do
  label="${name%%|*}"; url="${name##*|}"
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 3 "$url" 2>/dev/null || echo "---")
  printf "  %-9s %-32s [%s]\n" "$label" "$url" "$code"
done
