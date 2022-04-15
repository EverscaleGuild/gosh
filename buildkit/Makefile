DOCKER_REG      = 127.0.0.1:5000
VERSION         = latest
IMAGE_REFERENCE = ${DOCKER_REG}/goshfile
DOCKER          = docker


all: image build-example run-example

.PHONE: test
test:
	go test ./cmd

.PHONE: prepare
prepare:
	@echo ------------------------------------
	@echo Prepare local docker registry
	@echo ${DOCKER_REG}
	@echo ------------------------------------
	${DOCKER} rm -f reg || true
	${DOCKER} run -d --name reg -p ${DOCKER_REG}:5000 docker.io/library/registry:2
	## required for buildctl
	# ${DOCKER} rm -f buildkitd || true
	# ${DOCKER} run -d --name buildkitd --network host --privileged moby/buildkit:latest

.PHONE: jaeger
jaeger:
	@echo ------------------------------------
	@echo Run all-in-one jaeger
	@echo ------------------------------------
	${DOCKER} rm -f jaeger || true
	${DOCKER} run -d --name jaeger \
		-p 6831:6831/udp \
		-p 6832:6832/udp \
		-p 5778:5778 \
		-p 16686:16686 \
		-e SPAN_STORAGE_TYPE=badger \
		-e BADGER_EPHEMERAL=false \
		-e BADGER_DIRECTORY_VALUE=/badger/data \
		-e BADGER_DIRECTORY_KEY=/badger/key \
		-v "$$(pwd)"/badger:/badger \
		jaegertracing/all-in-one
	##
	## from https://www.docker.com/blog/engineering-update-buildkit-0-9-and-docker-buildx-0-6-releases/
	##
	@echo ------------------------------------
	@echo Set up custom buildx builder
	@echo Hint: buildx build require --load to make images visible in docker images
	@echo ------------------------------------
	${DOCKER} buildx rm builder || true
	${DOCKER} buildx create \
		--name builder \
		--driver docker-container \
		--driver-opt network=host \
		--driver-opt env.JAEGER_TRACE=localhost:6831 \
		--use

.PHONE: jaeger-off
jaeger-off:
	${DOCKER} rm -f jaeger || true
	${DOCKER} buildx rm builder || true

.PHONE: image
image:
	@echo ------------------------------------
	@echo Build buildkit-gosh \(aka frontend\)
	@echo ------------------------------------
	${DOCKER} buildx build --push -f Dockerfile -t ${IMAGE_REFERENCE}:${VERSION} .
	${DOCKER} pull ${IMAGE_REFERENCE}:${VERSION}

# Examples
.PHONE: build-example
build-example:
	@echo ------------------------------------
	@echo Build example image
	@echo ------------------------------------
	./examples/local_dev/build.sh build

.PHONE: run-example
run-example:
	@echo ------------------------------------
	@echo Run example image
	@echo ------------------------------------
	./examples/local_dev/build.sh run

.PHONE: save-example
save-example:
	@echo ------------------------------------
	@echo Save example image
	@echo ------------------------------------
	./examples/local_dev/build.sh save

.PHONE: public_image
public_image:
	@echo ------------------------------------
	@echo Build and push public image
	@echo ------------------------------------
	${DOCKER} buildx create --use
	${DOCKER} buildx build --push --platform linux/amd64,linux/arm64 -f Dockerfile -t teamgosh/goshfile:${VERSION} .
	${DOCKER} buildx rm
