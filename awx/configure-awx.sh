#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Configure AWX for the self-healing / canary-campaign demo.
# Docker port of the original 4-DeployTower/../utils/configureAnsible.sh:
#   * TOWER_URL   -> http://localhost:8052   (AWX on this VM, no kubectl)
#   * /api/v1/... -> /api/v2/...             (AWX only ships the v2 API)
#   * carts URL   -> the host-published prod carts (:8091) instead of a k8s LB
#
# Creates: a Dynatrace-API credential type + credential, a git project holding
# the playbooks, an inventory with all runtime vars, and the job templates
# (remediation, start-campaign, stop-campaign).
#
# Env in (export or put in ../.env):
#   DT_TENANT_URL   e.g. https://abc12345.live.dynatrace.com   (SaaS)
#                    or  https://<managed>/e/<envid>            (Managed)
#   DT_API_TOKEN    Dynatrace API token (events + problems.write)
#   GIT_REPO_URL    (optional) repo holding playbooks/  [default: upstream workshop]
#   GIT_BRANCH      (optional) [default: master]
#   AWX_URL         (optional) [default: http://localhost:8052]
#   AWX_USER/AWX_PASSWORD (optional) [default admin/dynatrace]
# -----------------------------------------------------------------------------
set -euo pipefail

# load ../.env if present
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${HERE}/../.env" ] && set -a && . "${HERE}/../.env" && set +a

AWX_URL="${AWX_URL:-http://localhost:8052}"
AWX_USER="${AWX_USER:-admin}"
AWX_PASSWORD="${AWX_PASSWORD:-dynatrace}"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/dynatrace-acm/dtacmworkshop.git}"
GIT_BRANCH="${GIT_BRANCH:-master}"

: "${DT_TENANT_URL:?Set DT_TENANT_URL (e.g. https://abc12345.live.dynatrace.com)}"
: "${DT_API_TOKEN:?Set DT_API_TOKEN (Dynatrace API token)}"

# Host IP the AWX containers use to reach the published prod carts (:8091)
HOST_IP="${HOST_IP:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
CARTS_PUBLISH_PORT="${CARTS_PUBLISH_PORT:-8091}"
CARTS_PROMOTION_URL="http://${HOST_IP}:${CARTS_PUBLISH_PORT}/carts/1/items/promotion"

AUTH=(--user "${AWX_USER}:${AWX_PASSWORD}")
JSON=(-H "Content-Type: application/json")
api() { curl -sk "${AUTH[@]}" "${JSON[@]}" "$@"; }

echo ">> AWX: ${AWX_URL}   carts promotion: ${CARTS_PROMOTION_URL}"

# 1) Dynatrace API credential type + credential -------------------------------
DTAPICREDTYPE=$(api -X POST "${AWX_URL}/api/v2/credential_types/" --data '{
  "name": "dt-api",
  "kind": "cloud",
  "description": "Dynatrace API Authentication Token",
  "inputs": { "fields": [ { "secret": true, "type": "string", "id": "dt_api_token", "label": "Dynatrace API Token" } ], "required": ["dt_api_token"] },
  "injectors": { "extra_vars": { "DYNATRACE_API_TOKEN": "{{dt_api_token}}" } }
}' | jq -r '.id // empty')
# reuse if it already exists
[ -z "$DTAPICREDTYPE" ] && DTAPICREDTYPE=$(api "${AWX_URL}/api/v2/credential_types/?name=dt-api" | jq -r '.results[0].id')
echo "   credential_type dt-api id=$DTAPICREDTYPE"

DTCRED=$(api -X POST "${AWX_URL}/api/v2/credentials/" --data '{
  "name": "Dynatrace API token",
  "credential_type": '"$DTAPICREDTYPE"',
  "organization": 1,
  "inputs": { "dt_api_token": "'"$DT_API_TOKEN"'" }
}' | jq -r '.id // empty')
[ -z "$DTCRED" ] && DTCRED=$(api "${AWX_URL}/api/v2/credentials/?name=Dynatrace%20API%20token" | jq -r '.results[0].id')
echo "   credential id=$DTCRED"

# 2) Project (git) holding the playbooks --------------------------------------
PROJECT_ID=$(api -X POST "${AWX_URL}/api/v2/projects/" --data '{
  "name": "self-healing",
  "organization": 1,
  "scm_type": "git",
  "scm_url": "'"$GIT_REPO_URL"'",
  "scm_branch": "'"$GIT_BRANCH"'",
  "scm_clean": true,
  "scm_update_on_launch": true
}' | jq -r '.id // empty')
[ -z "$PROJECT_ID" ] && PROJECT_ID=$(api "${AWX_URL}/api/v2/projects/?name=self-healing" | jq -r '.results[0].id')
echo "   project id=$PROJECT_ID (syncing...)"
sleep 45

# 3) Inventory with all runtime variables -------------------------------------
INV_VARS="---
tenanturl: \"${DT_TENANT_URL}\"
carts_promotion_url: \"${CARTS_PROMOTION_URL}\"
commentuser: \"Ansible Playbook\"
tower_user: \"${AWX_USER}\"
tower_password: \"${AWX_PASSWORD}\"
dtcommentapiurl: \"{{tenanturl}}/api/v1/problem/details/{{pid}}/comments?Api-Token={{DYNATRACE_API_TOKEN}}\"
dteventapiurl: \"{{tenanturl}}/api/v1/events/?Api-Token={{DYNATRACE_API_TOKEN}}\""
INVENTORY_ID=$(api -X POST "${AWX_URL}/api/v2/inventories/" --data "$(jq -n --arg v "$INV_VARS" '{name:"inventory",organization:1,variables:$v}')" | jq -r '.id // empty')
[ -z "$INVENTORY_ID" ] && INVENTORY_ID=$(api "${AWX_URL}/api/v2/inventories/?name=inventory" | jq -r '.results[0].id')
echo "   inventory id=$INVENTORY_ID"

# 4) Job templates ------------------------------------------------------------
REMEDIATION_ID=$(api -X POST "${AWX_URL}/api/v2/job_templates/" --data '{
  "name": "remediation", "job_type": "run",
  "inventory": '"$INVENTORY_ID"', "project": '"$PROJECT_ID"',
  "playbook": "playbooks/remediation.yaml", "ask_variables_on_launch": true
}' | jq -r '.id // empty')
[ -z "$REMEDIATION_ID" ] && REMEDIATION_ID=$(api "${AWX_URL}/api/v2/job_templates/?name=remediation" | jq -r '.results[0].id')
echo "   job_template remediation id=$REMEDIATION_ID"

STOP_ID=$(api -X POST "${AWX_URL}/api/v2/job_templates/" --data '{
  "name": "stop-campaign", "job_type": "run",
  "inventory": '"$INVENTORY_ID"', "project": '"$PROJECT_ID"',
  "playbook": "playbooks/campaign.yaml",
  "extra_vars": "---\npromotion_rate: \"0\"\ndt_application: \"carts\"\ndt_environment: \"prod\""
}' | jq -r '.id // empty')
[ -z "$STOP_ID" ] && STOP_ID=$(api "${AWX_URL}/api/v2/job_templates/?name=stop-campaign" | jq -r '.results[0].id')
echo "   job_template stop-campaign id=$STOP_ID"

# stop-campaign's remediation_action points back at its own launch endpoint
api -X PATCH "${AWX_URL}/api/v2/job_templates/${STOP_ID}/" --data '{
  "extra_vars": "---\npromotion_rate: \"0\"\nremediation_action: \"'"${AWX_URL}"'/api/v2/job_templates/'"${STOP_ID}"'/launch/\"\ndt_application: \"carts\"\ndt_environment: \"prod\""
}' >/dev/null

START_ID=$(api -X POST "${AWX_URL}/api/v2/job_templates/" --data '{
  "name": "start-campaign", "job_type": "run",
  "inventory": '"$INVENTORY_ID"', "project": '"$PROJECT_ID"',
  "playbook": "playbooks/campaign.yaml",
  "extra_vars": "---\npromotion_rate: \"50\"\nremediation_action: \"'"${AWX_URL}"'/api/v2/job_templates/'"${STOP_ID}"'/launch/\"\ndt_application: \"carts\"\ndt_environment: \"prod\"",
  "ask_variables_on_launch": true
}' | jq -r '.id // empty')
[ -z "$START_ID" ] && START_ID=$(api "${AWX_URL}/api/v2/job_templates/?name=start-campaign" | jq -r '.results[0].id')
echo "   job_template start-campaign id=$START_ID"

# 5) Attach the Dynatrace credential to every template ------------------------
for t in "$REMEDIATION_ID" "$STOP_ID" "$START_ID"; do
  api -X POST "${AWX_URL}/api/v2/job_templates/${t}/credentials/" --data '{ "id": '"$DTCRED"' }' >/dev/null || true
done

echo ""
echo "------------------------------------------------------------------"
echo " AWX configured. In Dynatrace, set the Ansible/webhook remediation"
echo " notification to launch the remediation job template:"
echo "   ${AWX_URL}/api/v2/job_templates/${REMEDIATION_ID}/launch/"
echo " (basic auth ${AWX_USER}/******).  Start the demo canary with:"
echo "   start-campaign  (id ${START_ID})   -> promotion 50%"
echo "------------------------------------------------------------------"
