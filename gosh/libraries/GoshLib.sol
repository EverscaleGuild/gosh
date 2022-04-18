pragma ton-solidity >=0.54.0;

library GoshLib {
    function buildWalletCode(
        TvmCell originalCode,
        uint256 pubkey,
        string version
    ) public returns (TvmCell) {
        TvmBuilder b;
        b.store(pubkey);
        b.store(version);
        return tvm.setCodeSalt(originalCode, b.toCell());
    }

    function buildRepositoryCode(
        TvmCell originalCode,
        address gosh,
        address dao,
        string version
    ) public returns (TvmCell) {
        TvmBuilder b;
        b.store(gosh);
        b.store(dao);
        b.store(version);
        return tvm.setCodeSalt(originalCode, b.toCell());
    }

    function buildSnapshotCode(
        TvmCell originalCode,
        address repo,
        string version
    ) public returns (TvmCell) {
        TvmBuilder b;
        b.store(repo);
        b.store(version);
        return tvm.setCodeSalt(originalCode, b.toCell());
    }
    
    function buildCommitCode(
        TvmCell originalCode,
        address repo,
        string version
    ) public returns (TvmCell) {
        TvmBuilder b;
        b.store(repo);
        b.store(version);
        return tvm.setCodeSalt(originalCode, b.toCell());
    }
    
    function buildBlobCode(
        TvmCell originalCode,
        string name,
        string version
    ) public returns (TvmCell) {
        TvmBuilder b;
        b.store(name);
        b.store(version);
        return tvm.setCodeSalt(originalCode, b.toCell());
    }
    
    function buildTagCode(
        TvmCell originalCode,
        address repo,
        string nametag,
        string version
    ) public returns (TvmCell) {
        TvmBuilder b;
        b.store(repo);
        b.store(nametag);
        b.store(version);
        return tvm.setCodeSalt(originalCode, b.toCell());
    }
}
