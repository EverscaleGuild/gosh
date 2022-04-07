/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.54.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "Upgradable.sol";
import "repository.sol";

/* Root contract of gosh */
contract Gosh is Upgradable {
    string version = "0.0.1";
    TvmCell m_RepositoryCode;
    TvmCell m_RepositoryData;
    TvmCell m_CommitCode;
    TvmCell m_CommitData;
    TvmCell m_BlobCode;
    TvmCell m_BlobData;
    TvmCell m_codeSnapshot;
    TvmCell m_dataSnapshot;

    modifier onlyOwner {
        require(msg.pubkey() == tvm.pubkey(), 500);
        _;
    }

    constructor() public {
        tvm.accept();
    }

    function _composeRepoStateInit(string name) internal view returns(TvmCell) {
        TvmBuilder b;
        b.store(address(this));
        b.store(name);
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_RepositoryCode, b.toCell());
        return tvm.buildStateInit(deployCode, m_RepositoryData);
    }

    function deployRepository(uint256 pubkey, string name) public view {
        require(msg.value > 2.6 ton, 100);
        require(pubkey > 0, 101);
        tvm.accept();

        TvmCell s1 = _composeRepoStateInit(name);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        new Repository {stateInit: s1, value: 0.4 ton, wid: 0}(pubkey, name);
        Repository(addr).setCommit{value: 0.2 ton}(m_CommitCode, m_CommitData);
        Repository(addr).setBlob{value: 0.2 ton}(m_BlobCode, m_BlobData);
        Repository(addr).setSnapshot{value: 0.2 ton}(m_codeSnapshot, m_dataSnapshot);
        Repository(addr).deployNewSnapshot{value:1.5 ton}("master");
    }

    function onCodeUpgrade() internal override {}

    //Setters

    function setRepository(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_RepositoryCode = code;
        m_RepositoryData = data;
    }

    function setCommit(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_CommitCode = code;
        m_CommitData = data;
    }

    function setBlob(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_BlobCode = code;
        m_BlobData = data;
    }

    function setSnapshot(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_codeSnapshot = code;
        m_dataSnapshot = data;
    }

    //Getters

    function getAddrRepository(string name) external view returns(address) {
        TvmCell s1 = _composeRepoStateInit(name);
        return address.makeAddrStd(0, tvm.hash(s1));
    }

    function getRepositoryCode() external view returns(TvmCell) {
        return m_RepositoryCode;
    }

    function getCommitCode() external view returns(TvmCell) {
        return m_CommitCode;
    }

    function getBlobCode() external view returns(TvmCell) {
        return m_BlobCode;
    }
}
