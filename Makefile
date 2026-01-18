DOCKER_IMAGE ?= openxcresulttool-swift:6.2
DOCKER_PLATFORM ?=
WORKDIR ?= /work
TEST_ARGS ?=
TEST_TIMEOUT ?= 30
WASM_IMAGE ?= openxcresulttool-wasm:6.2.3
WASM_PLATFORM ?=
WASM_SDK_ID ?= swift-6.2.3-RELEASE_wasm
WASM_BUILD_ARGS ?= --product OpenXCResultTool

DOCKER_PLATFORM_FLAG := $(if $(DOCKER_PLATFORM),--platform=$(DOCKER_PLATFORM),)
DOCKER_CMD = docker run --rm $(DOCKER_PLATFORM_FLAG) -v "$(PWD)":$(WORKDIR) -w $(WORKDIR) $(DOCKER_IMAGE)
DOCKER_BUILD_CMD = docker build $(DOCKER_PLATFORM_FLAG) -t $(DOCKER_IMAGE) -f Dockerfile .
WASM_PLATFORM_FLAG := $(if $(WASM_PLATFORM),--platform=$(WASM_PLATFORM),)
WASM_CMD = docker run --rm $(WASM_PLATFORM_FLAG) -v "$(PWD)":$(WORKDIR) -w $(WORKDIR) $(WASM_IMAGE)
WASM_BUILD_CMD = docker build $(WASM_PLATFORM_FLAG) -t $(WASM_IMAGE) -f Dockerfile.wasm .

.PHONY: linux-image linux-build linux-test wasm-image wasm-build

linux-image:
	$(DOCKER_BUILD_CMD)

linux-build:
	$(DOCKER_CMD) swift build

linux-test:
	$(DOCKER_CMD) bash -lc "timeout $(TEST_TIMEOUT) swift test $(TEST_ARGS)"

wasm-image:
	$(WASM_BUILD_CMD)

wasm-build:
	$(WASM_CMD) swift build --swift-sdk $(WASM_SDK_ID) $(WASM_BUILD_ARGS)
