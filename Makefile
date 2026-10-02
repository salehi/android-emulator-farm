# Headless Android emulator farm. One image per Android API 24-36.
# Nothing Android-related is installed on the host.
#
# Build one API at a time. The shared sdk stage is cached after the first
# successful build. A later API downloads only its system image and platform.
#
# The default BuildKit builder on this machine (meshcheck) cannot resolve
# deb.debian.org. Builds use the default Docker driver instead.
#
# IMAGE is the repository name, without a tag. Override it to pull prebuilt
# images: IMAGE=namespace/android-emulator-farm

COMPOSE := docker-compose -f docker-compose.yml
APIS := 24 25 26 27 28 29 30 31 32 33 34 35 36
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
farm: ## Start every API 24-36 emulator (about 2 GB RAM each, needs /dev/kvm)
	@echo "Starting emulator farm APIs $(APIS) from $(IMAGE). Each one needs about 2 GB RAM and /dev/kvm."
	$(COMPOSE) up -d

.PHONY: run-farm
run-farm: ## Pull and start every prebuilt emulator (IMAGE=namespace/...)
	@for api in $(APIS); do docker pull $(IMAGE):api$$api; done
	$(COMPOSE) up -d --no-build

.PHONY: ps
ps: ## Show farm containers
	$(COMPOSE) ps

.PHONY: down
down: ## Stop one emulator (API=) or the whole farm
	@if [ -n "$(API)" ]; then \
		$(COMPOSE) stop api$(API); \
	else \
		$(COMPOSE) down; \
	fi

.PHONY: help
help: ## Show this help
	@echo "Android emulator farm — targets:"
	@echo
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/{printf "  \033[36m%-8s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Build:  make image API=24"
	@echo "Run:    make run API=36 IMAGE=namespace/android-emulator-farm"
	@echo "APIs:   $(APIS)"
	@echo "Image:  $(IMAGE)"
