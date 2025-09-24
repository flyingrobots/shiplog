# Makefile - dockerized bats runner for SHIPLOG-Lite

IMAGE           ?= shiplog-tests
CONTEXT         ?= .
ENABLE_SIGNING  ?= false
DOCKER_BUILD_OPTS ?=
CONTAINER_NAME  ?= shiplog-tests-run
RUN_ID          := $(shell date +%s)

.PHONY: all build test build-signing test-signing clean

all: test

## Build the test image (no signing)
build:
	docker build $(DOCKER_BUILD_OPTS) \
		--build-arg ENABLE_SIGNING=$(ENABLE_SIGNING) \
		-t $(IMAGE) $(CONTEXT)

test: build
	- docker rm -f $(CONTAINER_NAME) >/dev/null 2>&1 || true
	docker run --rm --name $(CONTAINER_NAME) -v "$(CURDIR)":/workspace $(IMAGE)

## Convenience: force-signing build
build-signing:
	$(MAKE) build ENABLE_SIGNING=true

test-signing:
	$(MAKE) DOCKER_BUILD_OPTS="$(DOCKER_BUILD_OPTS)" build-signing
	- docker rm -f $(CONTAINER_NAME)-signing >/dev/null 2>&1 || true
	docker run --rm --name $(CONTAINER_NAME)-signing -v $(CURDIR):/workspace $(IMAGE)

## Clean local dangling images/containers (non-destructive)
clean:
	@echo "Nothing to clean inside repo. Use docker system prune -f at your own risk."
progress:
	@bash scripts/update-task-progress.sh
	@echo "Progress bars updated."
