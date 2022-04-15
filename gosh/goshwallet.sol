/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.58.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "Upgradable.sol";
import "gosh.sol";
import "repository.sol";
import "commit.sol";
import "tag.sol";
import "./libraries/GoshLib.sol";

/* Root contract of gosh */
contract GoshWallet is Upgradable {
    uint constant ERR_NO_SALT = 100;
    uint constant ERR_SENDER_NOT_DAO = 102;
    uint constant ERR_ZERO_ROOT_KEY = 103;
    uint constant ERR_ZERO_ROOT_GOSH = 106;
    uint constant ERR_LOW_VALUE = 104;
    uint constant ERR_NOT_ROOT_REPO = 105;
    uint constant ERR_INVALID_SENDER = 107;
    uint constant ERR_LOW_BALANCE = 108;

    uint128 constant FEE_DEPLOY_REPO = 3 ton;
    uint128 constant FEE_DEPLOY_COMMIT = 3 ton;

    string public version;
    uint256 static _rootRepoPubkey;
    address _rootgosh;
    address _goshdao;
    TvmCell m_RepositoryCode;
    TvmCell m_RepositoryData;
    TvmCell m_CommitCode;
    TvmCell m_CommitData;
    TvmCell m_BlobCode;
    TvmCell m_BlobData;

    modifier onlyOwner {
        require(msg.pubkey() == tvm.pubkey(), 100);
        _;
    }

    modifier onlyRootRepoKey {
        require(msg.pubkey() == _rootRepoPubkey, ERR_NOT_ROOT_REPO);
        _;
    }

    modifier minValue(uint128 val) {
        require(msg.value >= val, ERR_LOW_VALUE);
        _;
    }

    modifier senderIs(address sender) {
        require(msg.sender == sender, ERR_INVALID_SENDER);
        _;
    }

    modifier accept() {
        tvm.accept();
        _;
    }

    constructor(
        TvmCell commitCode,
        TvmCell commitData,
        TvmCell blobCode,
        TvmCell blobData,
        TvmCell repositoryCode,
        TvmCell repositoryData
    ) public {
        (_goshdao, _rootgosh, version) = _unpackSalt();
        require(_goshdao == msg.sender, ERR_SENDER_NOT_DAO);
        require(_rootgosh.value != 0, ERR_ZERO_ROOT_GOSH);
        require(_rootRepoPubkey != 0, ERR_ZERO_ROOT_KEY);
        m_CommitCode = commitCode;
        m_BlobCode = blobCode;
        m_RepositoryCode = repositoryCode;

        m_CommitData = commitData;
        m_BlobData = blobData;
        m_RepositoryData = repositoryData;
    }

    function deployRepository(
        string nameRepo
    ) public view onlyRootRepoKey accept {
        Gosh(_rootgosh).deployRepository{
            value: FEE_DEPLOY_REPO, bounce: true, flag: 2
        }(_rootRepoPubkey, nameRepo, _goshdao);
    }
    
    function deployCommit(
        string repoName,
        string branchName,
        string commitName,
        string fullCommit,
        address parent
    ) public view onlyOwner accept {
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deployCommit{
            value: FEE_DEPLOY_COMMIT, bounce: true, flag: 2 
        }(tvm.pubkey(), branchName, commitName, fullCommit, parent);
    }

    function topupCommit(
        string repoName,
        string branchName,
        string commit,
        uint128 value
    ) public view onlyOwner {
        require(address(this).balance > value + 1 ton, ERR_LOW_BALANCE);
        tvm.accept();
        address commitAddr = _buildCommitAddr(repoName, branchName, commit);
        commitAddr.transfer(value, true, 3);
    }
    
    function deployBlob(
        string repoName,
        string branchName,
        string commit,
        string blobName,
        string fullBlob
    ) public view onlyOwner accept {
        address commitAddr = _buildCommitAddr(repoName, branchName, commit);
        Commit(commitAddr).deployBlob{value: 2.8 ton}(tvm.pubkey(), blobName, fullBlob);
    }
    
    function deployTag(
        string repoName,
        string nametag,
        string nameCommit,
        address commit
    ) public view onlyOwner accept {
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deployTag{value: 2.8 ton}(tvm.pubkey(), nametag, nameCommit, commit);
    }

    // TODO remove or not???
    function onCodeUpgrade() internal override {}

    //Setters
    
    function setRepository(TvmCell code, TvmCell data) public 
        senderIs(_goshdao) accept {
        m_RepositoryCode = code;
        m_RepositoryData = data;
    }

    function setCommit(TvmCell code, TvmCell data) public 
        senderIs(_goshdao) accept {
        m_CommitCode = code;
        m_CommitData = data;
    }

    function setBlob(TvmCell code, TvmCell data) public 
        senderIs(_goshdao) accept {
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
        return tvm.pubkey();
    }

    //
    // Internals
    //

    function _unpackSalt() private pure returns (address, address, string) {
        optional(TvmCell) optsalt = tvm.codeSalt(tvm.code());
        require(optsalt.hasValue(), ERR_NO_SALT);
        return optsalt.get().toSlice().decode(address, address, string);
    }

    function _buildRepositoryAddr(string name) private view returns (address) {
        TvmCell deployCode = GoshLib.buildRepositoryCode(
            m_RepositoryCode, address(this), name, version
        );
        return address(tvm.hash(tvm.buildStateInit(deployCode, m_RepositoryData)));
    }

    function _buildCommitAddr(
        string repoName,
        string branch,
        string commit
    ) private view returns(address) {
        address repo = _buildRepositoryAddr(repoName);
        TvmCell deployCode = GoshLib.buildCommitCode(m_CommitCode, repo, branch, version);
        TvmCell state = tvm.buildStateInit({
            code: deployCode, 
            contr: Commit,
            varInit: {_nameCommit: commit}
        });
        return address(tvm.hash(state));
    }
}
