#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Stand up AWX 17.1.0 (Ansible Tower's open-source successor) on this single VM
# using its Docker Compose installer. Running the installer IS an Ansible play,
# so this doubles as the first "practice Ansible" step of the workshop.
#
# Prereqs on the VM (see ../README.md):
#   docker + docker compose, ansible-core, python3, git,
#   and the python 'docker' SDK  (pip3 install docker docker-compose)
#
# Result: AWX UI at http://<vm>:8052  (login admin / dynatrace)
# -----------------------------------------------------------------------------
set -euo pipefail

AWX_VERSION="17.1.0"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${HERE}/.build"

command -v git >/dev/null     || { echo "git is required"; exit 1; }
command -v docker >/dev/null  || { echo "docker is required"; exit 1; }
command -v ansible-playbook >/dev/null || { echo "ansible-core is required (pip3 install ansible-core)"; exit 1; }

echo ">> Cloning AWX ${AWX_VERSION} installer..."
rm -rf "${BUILD_DIR}"
git clone --depth 1 --branch "${AWX_VERSION}" https://github.com/ansible/awx.git "${BUILD_DIR}"

echo ">> Running the AWX installer with our pinned inventory..."
cd "${BUILD_DIR}/installer"
ansible-playbook -i "${HERE}/inventory" install.yml

echo ""
echo "------------------------------------------------------------------"
echo " AWX is starting. It runs migrations on first boot (a few minutes)."
echo " UI:    http://<this-vm>:8052"
echo " Login: admin / dynatrace"
echo ""
echo " Watch progress:   docker logs -f awx_task"
echo " When ready, wire up the job templates:  ./configure-awx.sh"
echo "------------------------------------------------------------------"
