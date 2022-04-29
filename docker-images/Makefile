DOCKER              ?= docker
DOCKER_BUILDER_NAME ?= public-gosh-builder
DOCKER_BUILDX       ?= ${DOCKER} buildx --builder ${DOCKER_BUILDER_NAME} build
PLATFORM            ?= linux/amd64,linux/arm/v7,linux/arm64,linux/ppc64le,linux/riscv64,linux/s390x
PROGRESS            ?= plain

GIT_COMMIT := $(shell git rev-parse HEAD)
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)

# main ==> docker:latest
ifeq "${GIT_BRANCH}" "main"
	GIT_BRANCH := "latest"
endif

all: sign-cli git-remote-gosh goshfile image-hash

.PHONE: clean
clean:
	@echo === $@
	${DOCKER} buildx rm ${DOCKER_BUILDER_NAME} || true

.PHONE: prepare-builder
prepare-builder:
	@echo === $@
	( ${DOCKER} buildx inspect ${DOCKER_BUILDER_NAME} ) || ${DOCKER} buildx create \
		--name ${DOCKER_BUILDER_NAME} \
		--driver docker-container

.PHONE: sign-cli
sign-cli: prepare-builder
	@echo === $@
	${DOCKER_BUILDX} \
		--push \
		--progress=${PROGRESS} \
		--platform ${PLATFORM} \
		-t teamgosh/sign-cli:${GIT_COMMIT} \
		-t teamgosh/sign-cli:${GIT_BRANCH} \
		\
		-f sign-cli/Dockerfile \
		../content-signature


.PHONE: git-remote-gosh
git-remote-gosh: prepare-builder
	@echo === $@
	${DOCKER_BUILDX} \
		--push \
		--progress=${PROGRESS} \
		--platform ${PLATFORM} \
		-t teamgosh/git-remote-gosh:${GIT_COMMIT} \
		-t teamgosh/git-remote-gosh:${GIT_BRANCH} \
		\
		-f git-remote-gosh/Dockerfile \
		..

.PHONE: goshfile
goshfile: prepare-builder
	@echo === $@
	${DOCKER_BUILDX} \
		--push \
		--progress=${PROGRESS} \
		--platform ${PLATFORM} \
		-t teamgosh/goshfile:${GIT_COMMIT} \
		-t teamgosh/goshfile:${GIT_BRANCH} \
		\
		-f goshfile/Dockerfile \
		../buildkit

.PHONE: image-hash
image-hash: prepare-builder
	@echo === $@
	${DOCKER_BUILDX} \
		--push \
		--progress=${PROGRESS} \
		--platform ${PLATFORM} \
		-t teamgosh/image-hash:${GIT_COMMIT} \
		-t teamgosh/image-hash:${GIT_BRANCH} \
		\
		-f image-hash/Dockerfile \
		..
