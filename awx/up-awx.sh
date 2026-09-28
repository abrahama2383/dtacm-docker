#!/usr/bin/env bash
# Bring up hand-rendered AWX 17.1.0 (the 17.1.0 installer can't run on a modern
# ansible-core). Copies awx/awxcompose/* into /var/lib/awx/awxcompose and starts
# it with the docker compose plugin. First web boot runs DB migrations (~3-5 min)
# and creates the admin user from environment.sh (admin / dynatrace).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST=/var/lib/awx/awxcompose

sudo mkdir -p "$DEST/redis_socket" /var/lib/awx/pgdocker/12/data /var/lib/awx/projects
sudo chmod 777 "$DEST/redis_socket"          # redis (non-root) creates the socket here
sudo cp "$HERE/awxcompose/"{docker-compose.yml,environment.sh,credentials.py,nginx.conf,redis.conf,SECRET_KEY} "$DEST/"

sudo docker compose -f "$DEST/docker-compose.yml" up -d

cat <<EOF

AWX starting. First boot runs DB migrations (~3-5 min) then creates admin/dynatrace.
  UI:     http://<this-vm>:8052   (tunnel: -L 8052:localhost:8052)
  Watch:  sudo docker logs -f awx_task 2>&1 | grep -iE 'migrat|Ready|error'
  Then:   ./configure-awx.sh   (creates the self-healing job templates)
EOF
