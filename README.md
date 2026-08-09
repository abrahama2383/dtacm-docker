# Dynatrace ACM Workshop — Docker edition (single VM)

A **Docker Compose** port of the [dtacmworkshop](https://github.com/dynatrace-acm/dtacmworkshop)
"Unbreakable DevOps Pipeline" so the whole thing runs on **one VM** instead of a
GKE/AKS cluster — built for practising **Jenkins** and **Ansible (AWX)**.

Same story as the original:

1. **Jenkins** pipeline deploys SockShop `carts` to a **dev/staging** stage
2. **JMeter** drives load against carts
3. **Dynatrace quality gate** approves/rejects promotion to **production**
4. **AWX** (Ansible Tower's OSS successor) does **self-healing**: Dynatrace
   detects a bad production build and launches a remediation playbook that rolls
   the carts feature-flag back.

Everything is containers on a single Docker host — no Kubernetes.

---

## What changed vs. the original

| Original (Kubernetes)                              | Here (Docker on one VM)                                             |
|----------------------------------------------------|--------------------------------------------------------------------|
| GKE/AKS 3-node cluster (`2-CreateCluster`)         | one VM with Docker + Compose                                       |
| `dev` / `production` **namespaces**                | two Compose projects: `sockshop-dev`, `sockshop-prod` (own nets)   |
| k8s **Service** (port 80 → targetPort 8080)        | an nginx **gateway** container per stage doing the same remap      |
| Jenkins k8s pod agents (mvn/docker/kubectl/jmeter) | one Jenkins controller image + host docker socket; JMeter container |
| `kubectl apply -f manifests/...`                   | `docker compose ... up -d`                                          |
| **Ansible Tower** on k8s + LoadBalancer            | **AWX 17.1.0** via its Docker Compose installer                    |
| OneAgent Operator + ActiveGate VM                  | one **host OneAgent** on the VM (`dynatrace/README.md`)            |
| Dynatrace steps always on                          | Dynatrace steps **toggleable** (`DT_ENABLED`, `.env`)             |

Original k8s manifests, playbooks and JMeter plans were reused; only the
delivery mechanism changed.

---

## Layout

```
compose/    SockShop stack (one file, launched as dev + prod) + nginx gateway
jenkins/    controller Dockerfile, plugins, JCasC, and the converted Jenkinsfile
awx/        AWX installer inventory + install/configure scripts
playbooks/  remediation.yaml + campaign.yaml (unchanged; HTTP-based, portable)
loadtest/   JMeter plans retargeted from cluster DNS to the carts gateway
monspec/    Dynatrace quality-gate spec
dynatrace/  host OneAgent + tagging notes
scripts/    up / down / status / wait-for-carts
```

---

## Prerequisites (on the VM)

* Linux VM (2+ vCPU, **8 GB RAM min**, 16 GB recommended — SockShop ×2 + Jenkins + AWX)
* `docker` + `docker compose` v2
* For AWX: `ansible-core`, `python3`, `git`, and the Python SDKs:
  `pip3 install docker docker-compose`
* (Optional) a Dynatrace tenant + API token for the gate/self-healing

## Port map

| Component          | URL                     |
|--------------------|-------------------------|
| SockShop dev UI    | http://localhost:8079   |
| SockShop prod UI   | http://localhost:8081   |
| prod carts (AWX)   | http://\<vm\>:8091      |
| Jenkins            | http://localhost:8080   |
| AWX                | http://localhost:8052   |

---

## Quickstart

```bash
cp .env.example .env
# edit .env: set DTACM_HOST_PATH (this dir on the VM) and DOCKER_GID
#   getent group docker | cut -d: -f3      # -> DOCKER_GID

make up          # network + SockShop dev & prod + Jenkins
make status
```

Open Jenkins (http://localhost:8080), run the **DeploySockShop** job:

* **BUILD = One** → good build → passes → promoted to production
* **BUILD = Two** → bad build → (with Dynatrace) fails the quality gate
* tick **DT_ENABLED** only after configuring a "Dynatrace Server" in Jenkins
  and installing OneAgent (see `dynatrace/README.md`). Left off, the pipeline
  runs pure Jenkins + Docker.

### Self-healing (Ansible/AWX)

```bash
make awx-install     # runs the AWX Ansible installer (~few min first boot)
# once AWX is up (docker logs -f awx_task):
make awx-config      # needs DT_TENANT_URL + DT_API_TOKEN in .env
```

Then in Dynatrace point a problem-notification at the printed `remediation`
job-template launch URL. Trigger the demo: run **start-campaign** (promotion
50% → bad carts behaviour) → Dynatrace opens a problem → it launches
**remediation** → carts promotion set back to 0% → recovered.

---

## Status / caveats (read me)

This was converted and reviewed statically; **it has not been run end-to-end
here** (no Docker in the authoring environment). Expect to iterate on:

* **`DOCKER_GID`** must match the VM's docker group or Jenkins can't use the socket.
* **AWX 17.1.0** is the last Compose-native AWX; first boot runs DB migrations
  and can take several minutes before the UI answers.
* **Dynatrace tag keys/contexts** in `monspec/monspec.json` and the
  `tagMatchRules` in `jenkins/Jenkinsfile` may need tweaking to match how your
  tenant tags Docker containers.
* The `performance-signature-dynatracesaas` Jenkins plugin needs a
  "Dynatrace Server" configured (Manage Jenkins → System) before `DT_ENABLED`.
* SockShop images are the original `dynatracesockshop/*` / `wmsegar/*` images
  (amd64). On Apple-silicon/arm64 VMs run with emulation or a x86 VM.

`make status` and `docker logs <name>` are your friends while bringing it up.
