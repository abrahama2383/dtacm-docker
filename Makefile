# Convenience wrapper around the scripts/ and compose files.
.PHONY: help up down destroy status jenkins dev prod carts-image awx-install awx-config logs-jenkins

help:
	@echo "make carts-image  - build the glibc carts image (dtacm/carts:1.0) - REQUIRED before dev/prod"
	@echo "make up          - network + SockShop dev & prod + Jenkins"
	@echo "make down         - stop core stack (keep data)"
	@echo "make destroy      - stop core stack AND delete volumes"
	@echo "make status       - health of all components"
	@echo "make dev          - (re)deploy SockShop dev only"
	@echo "make prod         - (re)deploy SockShop prod only"
	@echo "make jenkins      - (re)build + start Jenkins only"
	@echo "make awx-install  - install AWX 17.1.0 (Docker) via its Ansible installer"
	@echo "make awx-config   - create AWX job templates for self-healing"
	@echo "make logs-jenkins - follow Jenkins logs"

up:      ; @bash scripts/up.sh
down:    ; @bash scripts/down.sh
destroy: ; @bash scripts/down.sh -v
status:  ; @bash scripts/status.sh

carts-image:
	docker build -t dtacm/carts:1.0 carts-glibc

dev:
	docker compose -p sockshop-dev --env-file compose/dev.env \
	  -f compose/docker-compose.sockshop.yml up -d --remove-orphans

prod:
	docker compose -p sockshop-prod --env-file compose/prod.env \
	  -f compose/docker-compose.sockshop.yml \
	  -f compose/docker-compose.prod.override.yml up -d --remove-orphans

jenkins:
	docker compose -f jenkins/docker-compose.jenkins.yml up -d --build

awx-install:  ; @bash awx/install-awx.sh
awx-config:   ; @bash awx/configure-awx.sh
logs-jenkins: ; docker logs -f dtacm-jenkins
