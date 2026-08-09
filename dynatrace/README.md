# Dynatrace monitoring (optional but recommended)

The original workshop injected Dynatrace via the **OneAgent Operator** on
Kubernetes and a separate **ActiveGate VM**. On a single Docker VM you replace
both with **one host OneAgent** installed on the VM itself. It automatically
sees every container (SockShop, Jenkins, AWX) - no per-container sidecars, no
ActiveGate VM, no operator.

## 1. Install OneAgent on the VM (host-level, monitors all containers)

In your Dynatrace tenant: **Deploy Dynatrace → Start installation → Linux**,
copy the command, and run it on the VM. It looks like:

```bash
wget -O Dynatrace-OneAgent.sh "https://<envid>.live.dynatrace.com/api/v1/deployment/installer/agent/unix/default/latest?arch=x86&flavor=default" \
  --header="Authorization: Api-Token <PAAS_TOKEN>"
sudo /bin/sh Dynatrace-OneAgent.sh --set-app-log-content-access=true --set-infra-only=false
```

That is the Docker equivalent of `utils/deploy-dt-operator.sh` +
`utils/deployagsoftware.sh` from the original repo.

## 2. Tagging so the quality gate + self-healing target the right service

`docker-compose.sockshop.yml` stamps each service with container labels
(`app`, `stage`, `product`, `tier`, `version`). In Dynatrace, create
**automatically applied tags** from these Docker labels (Settings → Tags →
Automatically applied tags), e.g. tag `app` from label `app`, `stage` from
label `stage`. Then:

* `monspec/monspec.json` matches the carts service via `app:carts,stage:dev`.
* The AWX playbooks match via the same tag rules (see `playbooks/`).

Adjust the `tags` string in `monspec/monspec.json` and the `tagMatchRules` in
`jenkins/Jenkinsfile` if your tag keys/contexts differ.

## 3. Tokens

Put these in the project `.env`:

* `DT_TENANT_URL`  – `https://<envid>.live.dynatrace.com` (SaaS) or `https://<host>/e/<envid>` (Managed)
* `DT_API_TOKEN`   – API token with **Access problem/event feed, metrics** + **Create/read problems (comments)** + **Ingest events** scopes (used by Jenkins quality gate + AWX playbooks)
* `DT_PAAS_TOKEN`  – only for the OneAgent installer command above

## 4. Wire the self-healing notification

In Dynatrace: **Settings → Integration → Problem notifications → Ansible Tower**
(or a generic webhook). Point it at the AWX `remediation` job template launch
URL printed by `awx/configure-awx.sh`, with basic auth `admin / dynatrace`.
When Dynatrace opens a problem on the carts service, it launches the
remediation playbook, which sets the carts promotion rate back to 0% (rollback).
