# Makefile - dockerized bats runner for SHIPLOG-Lite

IMAGE           ?= shiplog-tests
CONTEXT         ?= .
ENABLE_SIGNING  ?= false
DOCKER_BUILD_OPTS ?=
CONTAINER_NAME  ?= shiplog-tests-run

.PHONY: all build test build-signing test-signing clean

all: test

## Build the test image (no signing)
build:
	docker build $(DOCKER_BUILD_OPTS) \
		--build-arg ENABLE_SIGNING=$(ENABLE_SIGNING) \
		-t $(IMAGE) $(CONTEXT)

## Run tests with the already-built image
test: build
	docker run --rm --name $(CONTAINER_NAME) -v $(PWD):/workspace $(IMAGE)

## Convenience: force-signing build
build-signing:
	$(MAKE) build ENABLE_SIGNING=true

## Convenience: run tests with signing enabled
test-signing:
	$(MAKE) DOCKER_BUILD_OPTS="$(DOCKER_BUILD_OPTS)" build-signing
	docker run --rm --name $(CONTAINER_NAME)-signing -v $(PWD):/workspace $(IMAGE)

## Clean local dangling images/containers (non-destructive)
clean:
	@echo "Nothing to clean inside repo. Use docker system prune -f at your own risk."
