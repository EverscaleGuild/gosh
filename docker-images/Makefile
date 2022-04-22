DOCKER              ?= docker
DOCKER_BUILDER_NAME ?= public-gosh-builder
DOCKER_BUILDX       ?= ${DOCKER} buildx --builder ${DOCKER_BUILDER_NAME} build
PLATFORM            ?= linux/amd64,linux/amd64/v2,linux/amd64/v3,linux/arm64,linux/riscv64,linux/ppc64le,linux/s390x,linux/386,linux/mips64le,linux/mips64,linux/arm/v7,linux/arm/v6

all: sign-cli git-remote-gosh

.PHONE: prepare-builder
prepare-builder:
	-${DOCKER} buildx rm ${DOCKER_BUILDER_NAME}
	${DOCKER} buildx create \
		--name ${DOCKER_BUILDER_NAME} \
		--driver docker-container

.PHONE: sign-cli
sign-cli: prepare-builder
	@echo Build $@
	${DOCKER_BUILDX} \
		--push \
		--progress=plain \
		--platform ${PLATFORM} \
		-f sign-cli/Dockerfile \
		-t teamgosh/sign-cli \
		../content-signature


.PHONE: git-remote-gosh
git-remote-gosh: prepare-builder
	@echo Build $@
	${DOCKER_BUILDX} \
		--push \
		--progress=plain \
		--platform ${PLATFORM} \
		-f git-remote-gosh/Dockerfile \
		-t teamgosh/git-remote-gosh \
		..
