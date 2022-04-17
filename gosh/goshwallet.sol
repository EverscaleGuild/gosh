/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.58.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "gosh.sol";
import "repository.sol";
import "commit.sol";
import "tag.sol";
import "./libraries/GoshLib.sol";

/* Root contract of gosh */
contract GoshWallet {
    uint constant ERR_NO_SALT = 100;
    uint constant ERR_SENDER_NOT_DAO = 102;
    uint constant ERR_ZERO_ROOT_KEY = 103;
    uint constant ERR_ZERO_ROOT_GOSH = 106;
    uint constant ERR_LOW_VALUE = 104;
    uint constant ERR_NOT_ROOT_REPO = 105;
    uint constant ERR_INVALID_SENDER = 107;
    uint constant ERR_LOW_BALANCE = 108;

    uint128 constant FEE_DEPLOY_REPO = 4 ton;
    uint128 constant FEE_DEPLOY_COMMIT = 4 ton;

    string public version;
    uint256 static _rootRepoPubkey;
    address static _rootgosh;
    address static _goshdao;
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
        m_CommitCode = commitCode;
        m_BlobCode = blobCode;
        m_RepositoryCode = repositoryCode;
        m_CommitData = commitData;
        m_BlobData = blobData;
        m_RepositoryData = repositoryData;
    }

    function deployRepository(
        string nameRepo
    ) public view onlyOwner accept {
        Gosh(_rootgosh).deployRepository{
            value: FEE_DEPLOY_REPO, bounce: true, flag: 2
        }(tvm.pubkey(), _rootRepoPubkey, nameRepo, _goshdao);
    }
    
    function deployCommit(
        string repoName,
        string branchName,
        string commitName,
        string fullCommit,
        address parent1,
        address parent2
    ) public view onlyOwner accept {
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deployCommit{
            value: FEE_DEPLOY_COMMIT, bounce: true, flag: 2 
        }(tvm.pubkey(), branchName, commitName, fullCommit, parent1, parent2);
    }
    
    function deployBranch(
        string repoName,
        string newName,
        string fromName
    ) public view onlyOwner accept {
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deployBranch{
            value: 2 ton, bounce: true, flag: 2 
        }(tvm.pubkey(), newName, fromName);
    }
    
    function deployDiff(
        string repoName,
        string name,
        string branch,
        string diff
    ) public view onlyOwner accept {
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deployDiff{
            value: 2 ton, bounce: true, flag: 2 
        }(tvm.pubkey(), name, branch, diff);
    }


    function topupCommit(
        string repoName,
        string commit,
        uint128 value
    ) public view onlyOwner {
        require(address(this).balance > value + 1 ton, ERR_LOW_BALANCE);
        tvm.accept();
        address commitAddr = _buildCommitAddr(repoName, commit);
        commitAddr.transfer(value, true, 3);
    }
    
    function deployBlob(
        string repoName,
        string commit,
        string blobName,
        string fullBlob
    ) public view onlyOwner accept {
        address commitAddr = _buildCommitAddr(repoName, commit);
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

    //Setters

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
    function _buildRepositoryAddr(string name) private view returns (address) {
        TvmCell deployCode = GoshLib.buildRepositoryCode(
            m_RepositoryCode, _rootgosh, _goshdao, version
        );
        return address(tvm.hash(tvm.buildStateInit({
            code: deployCode, 
            contr: Repository,
            varInit: {_name: name}
        })));
    }

    function _buildCommitAddr(
        string repoName,
        string commit
    ) private view returns(address) {
        address repo = _buildRepositoryAddr(repoName);
        TvmCell deployCode = GoshLib.buildCommitCode(m_CommitCode, repo, version);
        TvmCell state = tvm.buildStateInit({
            code: deployCode, 
            contr: Commit,
            varInit: {_nameCommit: commit}
        });
        return address(tvm.hash(state));
    }
}
