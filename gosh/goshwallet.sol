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
    uint constant ERR_DOUBLE_MSG = 109;

    uint128 constant FEE_DEPLOY_REPO = 4 ton;
    uint128 constant FEE_DEPLOY_COMMIT = 4 ton;

    string version = "0.1.0";
    uint256 static _rootRepoPubkey;
    address static _rootgosh;
    address static _goshdao;
    TvmCell m_RepositoryCode;
    TvmCell m_RepositoryData;
    TvmCell m_CommitCode;
    TvmCell m_CommitData;
    TvmCell m_BlobCode;
    TvmCell m_BlobData;
    
    // mapping to store hashes of inbound messages;
    mapping(uint256 => uint32) m_messages;
    // Each transaction is limited by gas, so we must limit count of iteration in loop.
    uint8 constant MAX_CLEANUP_MSGS = 30;

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
    ) public onlyOwner accept {
        gc();
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
    ) public onlyOwner accept {
        gc();
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deployCommit{
            value: FEE_DEPLOY_COMMIT, bounce: true, flag: 2 
        }(tvm.pubkey(), branchName, commitName, fullCommit, parent1, parent2);
    }
    
    function deployBranch(
        string repoName,
        string newName,
        string fromName,
        uint128 amountFiles
    ) public onlyOwner accept {
        gc();
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deployBranch{
            value: amountFiles * 1.5 ton + 1 ton, bounce: true, flag: 2 
        }(tvm.pubkey(), newName, fromName);
    }

    function deleteBranch(
        string repoName,
        string Name
    ) public onlyOwner accept {
        gc();
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deleteBranch{
            value: 1 ton, bounce: true, flag: 2
        }(tvm.pubkey(), Name);
    }
    
    function deployDiff(
        string repoName,
        string name,
        string branch,
        string diff
    ) public onlyOwner accept {
        gc();
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deployDiff{
            value: 2 ton, bounce: true, flag: 2 
        }(tvm.pubkey(), name, branch, diff);
    }


    function topupCommit(
        string repoName,
        string commit,
        uint128 value
    ) public onlyOwner {
        require(address(this).balance > value + 1 ton, ERR_LOW_BALANCE);
        tvm.accept();
        gc();
        address commitAddr = _buildCommitAddr(repoName, commit);
        commitAddr.transfer(value, true, 3);
    }
    
    function deployBlob(
        string repoName,
        string commit,
        string blobName,
        string fullBlob
    ) public onlyOwner accept {
        gc();
        address commitAddr = _buildCommitAddr(repoName, commit);
        Commit(commitAddr).deployBlob{value: 2.8 ton}(tvm.pubkey(), blobName, fullBlob);
    }
    
    function deployTag(
        string repoName,
        string nametag,
        string nameCommit,
        address commit
    ) public onlyOwner accept {
        gc();
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
    
    function afterSignatureCheck(TvmSlice body, TvmCell message) private inline
    returns (TvmSlice)
    {
        // load and drop message timestamp (uint64)
        (, uint32 expireAt) = body.decode(uint64, uint32);
        require(expireAt > now, 57);
        uint256 msgHash = tvm.hash(message);
        require(!m_messages.exists(msgHash), ERR_DOUBLE_MSG);
        m_messages[msgHash] = expireAt;
        return body;
    }

    /// @notice Allows to delete expired messages from dict.
    function gc() private {
        uint counter = 0;
        for ((uint256 msgHash, uint32 expireAt) : m_messages) {
            if (counter >= MAX_CLEANUP_MSGS) {
                break;
            }
            counter++;
            if (expireAt <= now) {
                delete m_messages[msgHash];
            }
        }
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

    function getVersion() external view returns(string) {
        return version;
    }
}
