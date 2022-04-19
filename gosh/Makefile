tvcs = daocreater.tvc gosh.tvc goshdao.tvc repository.tvc snapshot.tvc commit.tvc goshwallet.tvc blob.tvc tag.tvc
all: $(tvcs)

$(tvcs): %.tvc: %.sol
	everdev sol compile $^

clean:
	rm -f *.tvc *.abi.json
	rm -rf .solc_imports

rebuild: clean all
