DOCKER_IMAGE ?= openxcresulttool-swift:6.2
DOCKER_PLATFORM ?=
WORKDIR ?= /work
TEST_ARGS ?=
TEST_TIMEOUT ?= 600

DOCKER_PLATFORM_FLAG := $(if $(DOCKER_PLATFORM),--platform=$(DOCKER_PLATFORM),)
DOCKER_CMD = docker run --rm $(DOCKER_PLATFORM_FLAG) -v "$(PWD)":$(WORKDIR) -w $(WORKDIR) $(DOCKER_IMAGE)
DOCKER_BUILD_CMD = docker build $(DOCKER_PLATFORM_FLAG) -t $(DOCKER_IMAGE) -f Dockerfile .

.PHONY: linux-image linux-build linux-test

linux-image:
	$(DOCKER_BUILD_CMD)

linux-build:
	$(DOCKER_CMD) swift build

linux-test:
	$(DOCKER_CMD) bash -lc "timeout $(TEST_TIMEOUT) swift test $(TEST_ARGS)"
