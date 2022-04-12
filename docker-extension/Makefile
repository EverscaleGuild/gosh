IMAGE?=teamgosh/docker-extension
#IMAGE?=teamgosh-docker-extension
TAG?=1.0.0-alpha.2
LOCAL_TEMP_DIR=./.tmp/

.DEFAULT_GOAL := debug

build: ## Build service image to be deployed as a desktop extension
	-rm -rf $(LOCAL_TEMP_DIR)
	-mkdir $(LOCAL_TEMP_DIR)
	-cp -r ../content-signature $(LOCAL_TEMP_DIR)
	docker build \
	  --tag=$(IMAGE):$(TAG) \
	  --build-arg content_signature_local_dir="$(LOCAL_TEMP_DIR)" \
	  .
	-rm -rf $(LOCAL_TEMP_DIR)

install: build ## Install the extension
	docker extension install $(IMAGE):$(TAG)

update: build ## Update the extension
	docker extension update $(IMAGE):$(TAG)

debug: update ## Debug the extension
	docker extension dev debug $(IMAGE):$(TAG)

publish: ## Publish the extension
	-rm -rf $(LOCAL_TEMP_DIR)
	-mkdir $(LOCAL_TEMP_DIR)
	-cp -r ../content-signature $(LOCAL_TEMP_DIR)
	docker buildx build \
	  --platform linux/amd64,linux/arm64 \
	  --tag=$(IMAGE):$(TAG) \
	  --tag=$(IMAGE):latest \
	  --build-arg content_signature_local_dir="$(LOCAL_TEMP_DIR)" \
	  --push \
	  .
	-rm -rf $(LOCAL_TEMP_DIR)



.PHONY: build install update debug publish
