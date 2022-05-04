tvcs = daocreator.tvc gosh.tvc goshdao.tvc repository.tvc commit.tvc goshwallet.tvc blob.tvc tag.tvc goshconfig.tvc
all: $(tvcs)

$(tvcs): %.tvc: %.sol
	everdev sol compile $^

clean:
	rm -f *.tvc *.abi.json
	rm -rf .solc_imports

rebuild: clean all

build:
	everdev sol compile ${ARG}.sol
