/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.58.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "gosh.sol";
import "repository.sol";
import "commit.sol";
import "tag.sol";
import "./libraries/GoshLib.sol";
import "../smv/SMVAccount.sol";
import "../smv/Libraries/SMVConstants.sol";

/* Root contract of gosh */
contract GoshWallet is SMVAccount , IVotingResultRecipient{
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
    
    // mapping to store hashes of inbound messages;
    mapping(uint256 => uint32) m_messages;
    // Each transaction is limited by gas, so we must limit count of iteration in loop.
    uint8 constant MAX_CLEANUP_MSGS = 20;
    
    struct LastMsg {
        uint32 expireAt;
        uint256 msgHash;
    }

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
    TvmCell m_WalletCode;
    TvmCell m_WalletData;    
    LastMsg m_lastMsg;
    address _me;
    
    TvmCell m_SMVPlatformCode;
    TvmCell m_SMVClientCode;
    TvmCell m_SMVProposalCode;
    
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
    
    modifier saveMsg() {
        m_messages[m_lastMsg.msgHash] = m_lastMsg.expireAt;
        _;
    }
    
    modifier clean() {
        _;
        gc();
    }

    modifier minBalance(uint128 val) {
        require(address(this).balance > val + 1 ton, ERR_LOW_BALANCE);
        _;
    }

    constructor(
        TvmCell commitCode,
        TvmCell commitData,
        TvmCell blobCode,
        TvmCell blobData,
        TvmCell repositoryCode,
        TvmCell repositoryData,
        TvmCell WalletCode, 
        TvmCell WalletData,
         //added for SMV
        TvmCell lockerCode, 
        TvmCell platformCode,
        TvmCell clientCode,
        TvmCell proposalCode,
        address _tip3Root,
        address me)
     public SMVAccount (lockerCode, tvm.hash(platformCode), platformCode.depth(),
                         tvm.hash(clientCode), clientCode.depth(), tvm.hash(proposalCode),
                         proposalCode.depth(), _tip3Root) {
        m_CommitCode = commitCode;
        m_BlobCode = blobCode;
        m_RepositoryCode = repositoryCode;
        m_CommitData = commitData;
        m_BlobData = blobData;
        m_RepositoryData = repositoryData;
        m_WalletCode = WalletCode;
        m_WalletData = WalletData;
        _me = me;
        ///////////////////
        m_SMVPlatformCode = platformCode;
        m_SMVClientCode = clientCode;
        m_SMVProposalCode = proposalCode;
    }
    
    function _composeCommitStateInit(string _commit, address repo) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildCommitCode(m_CommitCode, repo, version);
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Commit, varInit: {_nameCommit: _commit}});
        return stateInit;
    }

    function deployRepository(
        string nameRepo
    ) public onlyOwner accept saveMsg clean {
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
        ) public onlyOwner accept saveMsg clean {
        _deployCommit(repoName, branchName, commitName, fullCommit, parent1, parent2);
    }

    function _deployCommit(
        string repoName,
        string branchName,
        string commitName,
        string fullCommit,
        address parent1,
        address parent2) internal view
    {
        address repo = _buildRepositoryAddr(repoName);
        TvmCell s1 = _composeCommitStateInit(commitName, repo);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        new Commit {stateInit: s1, value: 2 ton, wid: 0}(
            _goshdao, _rootgosh, _rootRepoPubkey, repoName, branchName, fullCommit, parent1, parent2, m_BlobCode, m_BlobData, m_WalletCode, m_WalletData);
    }
    
    function setCommit(
        string repoName,
        string branchName,
        string commit, string[] diffName, string[] diff) public view onlyOwner accept {
        require(diffName.length == diff.length, 115);
        if ((branchName == "main") || (branchName == "master")) {
            TvmBuilder b;

            uint256 id = tvm.hash(b.toCell()); 
            uint32 startTime = now + 1*60;
            uint32 finishTime = now + 5*60 + 7*24*60*60;
            startProposal (m_SMVPlatformCode, m_SMVProposalCode,  
                           id, b.toCell(), startTime, finishTime);
        } else {
            address repo = _buildRepositoryAddr(repoName);
            TvmCell s0 = _composeCommitStateInit(commit, repo);
            address addrC = address.makeAddrStd(0, tvm.hash(s0));
            Repository(repo).setCommit{value: 1 ton, bounce: true, flag: 2}(tvm.pubkey(), branchName, addrC);
            deployDiff(0, repoName, diffName, branchName, diff);
        }
    }
        
    function _composeBlobStateInit(string nameBlob, address repo) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildBlobCode(
            m_BlobCode, repo, version
        );
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Blob, varInit: {_nameBlob: nameBlob}});
        //return tvm.insertPubkey(stateInit, pubkey);
        return stateInit;
    }
    
    function deployBlob(
        string repoName, 
        string commit,
        string branch,
        string blobName, 
        string fullBlob, 
        string prevSha
        ) public onlyOwner accept saveMsg clean {
        _deployBlob(repoName, commit, branch, blobName, fullBlob, prevSha);
    }

    function _deployBlob(
        string repoName, 
        string commit,
        string branch,
        string blobName, 
        string fullBlob, 
        string prevSha) internal view
    {
        address repo = _buildRepositoryAddr(repoName);
        TvmCell s0 = _composeCommitStateInit(commit, repo);
        address addrC = address.makeAddrStd(0, tvm.hash(s0));
        TvmCell s1 = _composeBlobStateInit(blobName, repo);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        new Blob{stateInit: s1, value: 1 ton, wid: 0}(tvm.pubkey(), addrC, branch, fullBlob, prevSha, _rootgosh, _goshdao, _rootRepoPubkey, m_WalletCode, m_WalletData);
    }
    
    function setBlob(
        string repoName,
        string commitName,
        address[] blobs) public view onlyOwner accept {
        address repo = _buildRepositoryAddr(repoName);
        TvmCell s1 = _composeCommitStateInit(commitName, repo);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        Commit(addr).setBlobs{value: 1 ton, bounce: true, flag: 2}(tvm.pubkey(), blobs);
    }
    
    function setHEAD(
        string repoName,
        string branchName) public view onlyOwner accept {
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).setHEAD{value: 1 ton, bounce: true, flag: 2}(tvm.pubkey(), branchName);
    }
    
    function tryProposalResult (address proposal) public view onlyOwner accept
    {
        ISMVProposal(proposal).isCompleted{
            value: SMVConstants.VOTING_COMPLETION_FEE + SMVConstants.EPSILON_FEE} ();    
    }

    function isCompletedCallback(optional(bool) res, TvmCell propData) external override {
        //for tests
        lastVoteResult = res;
        //
/*
        if (res.hasValue()) {
            if (res.get()) {
                TvmSlice s = propData.toSlice();
                TvmSlice commitSlice = s.loadRefAsSlice();
                uint256 kind = commitSlice.decode(uint256);
                TvmSlice blob1Slice = s.loadRefAsSlice();
                TvmSlice blob2Slice = s.loadRefAsSlice();
                TvmSlice diff1Slice = s.loadRefAsSlice();
                if (kind == 0)
                {
                    (string repoName, string branchName, string commitName, string fullCommit, address parent1, address parent2) =
                        commitSlice.decode(string, string, string, string, address, address);
                    _deployCommit(repoName, branchName, commitName, fullCommit, parent1, parent2);

                    (string diffName, string diff) =  diff1Slice.decode(string, string);
                    _deployDiff(repoName, diffName, branchName, diff);
                    (string blobName, string fullBlob, string prevSha) = blob1Slice.decode(string, string, string);
                    _deployBlob(repoName, commitName, blobName, fullBlob, prevSha);
                    ( blobName,  fullBlob,  prevSha) = blob2Slice.decode(string, string, string);
                    _deployBlob(repoName, commitName, blobName, fullBlob, prevSha);
                }
            }
        }
*/
    }
    
    function deployBranch(
        string repoName,
        string newName,
        string fromName,
        uint128 amountFiles
    ) public view onlyOwner accept {
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deployBranch{
            value: amountFiles * 1.5 ton + 1 ton, bounce: true, flag: 2 
        }(tvm.pubkey(), newName, fromName);
    }

    function deleteBranch(
        string repoName,
        string Name
    ) public view onlyOwner accept {
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deleteBranch{
            value: 1 ton, bounce: true, flag: 2
        }(tvm.pubkey(), Name);
    }
    
    function deployDiff(
        uint128 index,
        string repoName,
        string[] name,
        string branch,
        string[] diff
    ) public view senderIs(_me) accept {
        require(index < name.length, 1000);
        _deployDiff(repoName, name[index], branch, diff[index]);
        index += 1;
        this.deployDiff{
            value: 1 ton, bounce: true, flag: 2
        }(index, repoName, name, branch, diff);
    }

    function _deployDiff(
        string repoName,
        string name,
        string branch,
        string diff
    ) private view  {
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
    
    function deployTag(
        string repoName,
        string nametag,
        string nameCommit,
        address commit
    ) public onlyOwner accept saveMsg clean{
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
        m_lastMsg = LastMsg(expireAt, msgHash);
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
