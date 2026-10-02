# Headless Android emulator farm. One prebuilt image per Android API, pulled
# from Docker Hub. Nothing Android-related is installed on the host.
#
# Images are built and published by GitHub Actions. emulators.json lists the
# APIs, and docker-compose.yml is generated from it with `make render`.
#
# Set IMAGE (repository, without a tag) to run images from another namespace.

# Prefer the Compose v2 plugin, fall back to the standalone docker-compose.
COMPOSE_BIN ?= $(shell docker compose version >/dev/null 2>&1 && echo "docker compose" || echo docker-compose)
COMPOSE := $(COMPOSE_BIN) -f docker-compose.yml
APIS := $(shell sed -n 's/^  api\([0-9][0-9]*\):$$/\1/p' docker-compose.yml)
API ?=
EMULATOR_API := $(or $(API),36)

.DEFAULT_GOAL := help

.PHONY: pull
pull: ## Pull the latest image for one API (API=36), or every API
	@if [ -n "$(API)" ]; then \
		$(COMPOSE) pull api$(API); \
	else \
		$(COMPOSE) pull; \
	fi

.PHONY: up
up: ## Start one emulator (API=36 by default). adb at 127.0.0.1:5000+API
	@echo "Starting Android API $(EMULATOR_API) (adb at 127.0.0.1:$$((5000 + $(EMULATOR_API))))."
	$(COMPOSE) up -d api$(EMULATOR_API)

.PHONY: farm
farm: ## Start every emulator (about 2 GB RAM each)
	@echo "Starting emulator farm APIs $(APIS). Each one needs about 2 GB RAM and /dev/kvm."
	$(COMPOSE) up -d

.PHONY: ps
ps: ## Show farm containers and their health
	$(COMPOSE) ps

.PHONY: logs
logs: ## Follow one emulator's log (API=36 by default)
	$(COMPOSE) logs -f api$(EMULATOR_API)

.PHONY: down
down: ## Stop one emulator (API=) or the whole farm
	@if [ -n "$(API)" ]; then \
		$(COMPOSE) stop api$(API); \
	else \
		$(COMPOSE) down; \
	fi

.PHONY: render
render: ## Regenerate files derived from emulators.json (needs jq)
	scripts/render.sh

.PHONY: check
check: ## Validate emulators.json and check generated files are current
	scripts/render.sh --check
	$(COMPOSE) config --quiet

.PHONY: help
help: ## Show this help
	@echo "Android emulator farm — targets:"
	@echo
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/{printf "  \033[36m%-7s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Run:    make up API=34"
	@echo "APIs:   $(APIS)"
