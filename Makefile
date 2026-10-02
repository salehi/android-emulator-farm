# Headless Android emulator farm. One image per Android API.
# Nothing Android-related is installed on the host.
#
# emulators.json lists the APIs. docker-compose.yml is generated from it with
# `make render`. Build one API at a time: the shared sdk stage is cached after
# the first build, and each later API downloads only its own system image.
#
# Builds use the classic Docker builder by default (BUILDX_BUILDER=default).
# Override it when a different buildx builder can reach deb.debian.org.
#
# IMAGE is the repository name, without a tag. Override it to pull prebuilt
# images: IMAGE=s4l3h1/android-emulator-farm

COMPOSE := docker-compose -f docker-compose.yml
APIS := $(shell sed -n 's/^  api\([0-9][0-9]*\):$$/\1/p' docker-compose.yml)
API ?=
EMULATOR_API := $(or $(API),36)
BUILDX_BUILDER ?= default
IMAGE ?= android-emulator-farm
export IMAGE

.DEFAULT_GOAL := help

.PHONY: image
image: ## Build one image (API=24 .. API=36)
	@test -n "$(API)" || { echo "Set API to one of: $(APIS)"; exit 1; }
	BUILDX_BUILDER=$(BUILDX_BUILDER) $(COMPOSE) build api$(API)

.PHONY: pull
pull: ## Pull one prebuilt image (API=36 IMAGE=namespace/android-emulator-farm)
	docker pull $(IMAGE):api$(EMULATOR_API)

.PHONY: up
up: ## Start one emulator (API=36 by default). adb at 127.0.0.1:5000+API
	@echo "Starting Android API $(EMULATOR_API) from $(IMAGE) (adb at 127.0.0.1:$$((5000 + $(EMULATOR_API))))."
	$(COMPOSE) up -d api$(EMULATOR_API)

.PHONY: run
run: pull ## Pull and start one prebuilt emulator (API=36 IMAGE=namespace/...)
	$(COMPOSE) up -d --no-build api$(EMULATOR_API)

.PHONY: farm
farm: ## Start every emulator from local images (about 2 GB RAM each)
	@echo "Starting emulator farm APIs $(APIS) from $(IMAGE). Each one needs about 2 GB RAM and /dev/kvm."
	$(COMPOSE) up -d

.PHONY: run-farm
run-farm: ## Pull and start every prebuilt emulator (IMAGE=namespace/...)
	@for api in $(APIS); do docker pull $(IMAGE):api$$api || exit 1; done
	$(COMPOSE) up -d --no-build

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
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/{printf "  \033[36m%-9s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Build:  make image API=24"
	@echo "Run:    make run API=36 IMAGE=s4l3h1/android-emulator-farm"
	@echo "APIs:   $(APIS)"
	@echo "Image:  $(IMAGE)"
