# -----------------------------------------------------------------------------
# Echo stack – Makefile helpers
# -----------------------------------------------------------------------------
# All targets assume you run them from the repo root.
# They wrap docker‑compose commands located in ./compose
# to avoid repeating long CLI strings.
# -----------------------------------------------------------------------------

COMPOSE        = docker compose --project-directory $(CURDIR)/compose

.PHONY: help up down restart restart-vllm restart-ui logs status update-all \
        shell-vllm shell-ui prune

help: ## Display available targets
	@echo "Echo stack — common shortcuts"
	@echo " make up            : Pull images and start stack"
	@echo " make down          : Stop stack and remove containers"
	@echo " make restart       : Restart all services"
	@echo " make restart-vllm  : Restart vLLM backend only"
	@echo " make restart-ui    : Restart OpenWebUI frontend only"
	@echo " make logs          : Tail container logs (follow)"
	@echo " make status        : Show compose service status"
	@echo " make update-all    : Pull new images and redeploy"
	@echo " make shell-vllm    : Open a shell inside vLLM container"
	@echo " make shell-ui      : Open a shell inside OpenWebUI container"
	@echo " make prune         : Docker system prune (dangerous!)"

up: ## Pull images and start stack
	$(COMPOSE) pull
	$(COMPOSE) up -d

down: ## Stop stack
	$(COMPOSE) down

restart: ## Restart all services
	$(COMPOSE) restart

restart-vllm: ## Restart only vLLM service
	$(COMPOSE) restart vllm-server

restart-ui: ## Restart only OpenWebUI service
	$(COMPOSE) restart openwebui

logs: ## Tail logs
	$(COMPOSE) logs -f --tail=100

status: ## Service status
	$(COMPOSE) ps

update-all: ## Pull new images & restart stack
	$(COMPOSE) pull
	$(COMPOSE) up -d

shell-vllm: ## Interactive shell in vLLM container
	docker exec -it vllm-server bash

shell-ui: ## Interactive shell in OpenWebUI container
	docker exec -it openwebui bash

prune: ## Reclaim disk space (containers, images, volumes)
	docker system prune -f