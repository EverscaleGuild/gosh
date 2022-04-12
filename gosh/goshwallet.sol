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
import "gosh.sol";
import "repository.sol";
import "commit.sol";
import "tag.sol";

/* Root contract of gosh */
contract GoshWallet is Upgradable {
    string version = "0.0.1";
    address _rootgosh;
    address _goshdao;
    uint256 static _rootRepoPubkey;
    uint256 static _pubkey;   
    TvmCell m_RepositoryCode;
    TvmCell m_RepositoryData;
    TvmCell m_CommitCode;
    TvmCell m_CommitData;
    TvmCell m_BlobCode;
    TvmCell m_BlobData;

    modifier onlyOwner {
        require(msg.pubkey() == _pubkey, 500);
        _;
    }

    constructor(address gosh) public {
        tvm.accept();
        _rootgosh = gosh;
        _goshdao = msg.sender;
    }

    function deployRepository(string nameRepo) public view {
        require(msg.value > 3 ton, 100);
        require(msg.pubkey() == _rootRepoPubkey, 121);
        tvm.accept();
        Gosh(_rootgosh).deployRepository{value: 2.8 ton}(_rootRepoPubkey, nameRepo, _goshdao);
    }
    
    function deployCommit(address repo, string nameBranch, string nameCommit, string fullCommit, address parent) public view onlyOwner {
        tvm.accept();
        Repository(repo).deployCommit{value: 2.8 ton}(_pubkey, nameBranch, nameCommit, fullCommit, parent);
    }
    
    function deployBlob(address commit, string nameBlob, string fullBlob) public view onlyOwner {
        tvm.accept();
        Commit(commit).deployBlob{value: 2.8 ton}(_pubkey, nameBlob, fullBlob);
    }
    
    function deployTag(address repo, string nametag, string nameCommit, address commit) public view onlyOwner {
        tvm.accept();
        Repository(repo).deployTag{value: 2.8 ton}(_pubkey, nametag, nameCommit, commit);
    }

    function onCodeUpgrade() internal override {}

    //Setters
    
    function setRepository(TvmCell code, TvmCell data) public  onlyOwner {
        require(msg.sender == _goshdao, 101);
        tvm.accept();
        m_RepositoryCode = code;
        m_RepositoryData = data;
    }

    function setCommit(TvmCell code, TvmCell data) public  onlyOwner {
        require(msg.sender == _goshdao, 101);
        tvm.accept();
        m_CommitCode = code;
        m_CommitData = data;
    }

    function setBlob(TvmCell code, TvmCell data) public  onlyOwner {
        require(msg.sender == _goshdao, 101);
        tvm.accept();
        m_BlobCode = code;
        m_BlobData = data;
    }

    //Getters

    function getAddrRootGosh() external view returns(address) {
        return _rootgosh;
    }

    function getAddrDao() external view returns(address) {
        return _goshdao;
    }

    function getRootPubkey() external view returns(uint256) {
        return _rootRepoPubkey;
    }

    function getWalletPubkey() external view returns(uint256) {
        return _pubkey;
    }
}
