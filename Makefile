DOCKER_IMAGE ?= swift:6.2
DOCKER_PLATFORM ?=
WORKDIR ?= /work

DOCKER_PLATFORM_FLAG := $(if $(DOCKER_PLATFORM),--platform=$(DOCKER_PLATFORM),)
DOCKER_CMD = docker run --rm $(DOCKER_PLATFORM_FLAG) -v "$(PWD)":$(WORKDIR) -w $(WORKDIR) $(DOCKER_IMAGE)

.PHONY: linux-build linux-test

linux-build:
	$(DOCKER_CMD) swift build

linux-test:
	$(DOCKER_CMD) swift test
