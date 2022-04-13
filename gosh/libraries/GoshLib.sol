pragma ton-solidity >=0.54.0;

library GoshLib {
    function buildWalletCode(
        TvmCell originalCode,
        address dao,
        address root,
        string version
    ) public returns (TvmCell) {
        TvmBuilder b;
        b.store(dao);
        b.store(root);
        b.store(version);
        return tvm.setCodeSalt(originalCode, b.toCell());
    }

    function buildRepositoryCode(
        TvmCell originalCode,
        address gosh,
        string name,
        string version
    ) public returns (TvmCell) {
        TvmBuilder b;
        b.store(gosh);
        b.store(name);
        b.store(version);
        return tvm.setCodeSalt(originalCode, b.toCell());
    }
}