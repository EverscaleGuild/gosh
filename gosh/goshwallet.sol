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

    constructor(
        TvmCell commitCode,
        TvmCell commitData,
        TvmCell blobCode,
        TvmCell blobData,
        TvmCell repositoryCode,
        TvmCell repositoryData,
         //added for SMV
        TvmCell lockerCode, 
        TvmCell platformCode,
        TvmCell clientCode,
        TvmCell proposalCode,
        address _tip3Root)
     public SMVAccount (lockerCode, tvm.hash(platformCode), platformCode.depth(),
                         tvm.hash(clientCode), clientCode.depth(), tvm.hash(proposalCode),
                         proposalCode.depth(), _tip3Root) {
        m_CommitCode = commitCode;
        m_BlobCode = blobCode;
        m_RepositoryCode = repositoryCode;
        m_CommitData = commitData;
        m_BlobData = blobData;
        m_RepositoryData = repositoryData;
        ///////////////////
        m_SMVPlatformCode = platformCode;
        m_SMVClientCode = clientCode;
        m_SMVProposalCode = proposalCode;
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
        address parent2, 

        string blobName1, string fullBlob1, string prevSha1,
        string blobName2, string fullBlob2, string prevSha2,
        string diffName, string diff
    ) public view onlyOwner accept {
        if ((branchName == "main") || (branchName == "master")) {
            TvmBuilder commitBuilder;
            uint256 proposalKind = 0;
            commitBuilder.store(proposalKind, repoName, branchName, commitName, fullCommit, parent1, parent2);
            
            TvmBuilder blob1Builder;
            blob1Builder.store(blobName1, fullBlob1, prevSha1);

            TvmBuilder blob2Builder;
            blob2Builder.store(blobName2, fullBlob2, prevSha2);

            TvmBuilder diff1Builder;
            diff1Builder.store(diffName, diff);

            TvmBuilder b;
            b.storeRef(commitBuilder);
            b.storeRef(blob1Builder);
            b.storeRef(blob2Builder);
            b.storeRef(diff1Builder);

            uint256 id = tvm.hash(b.toCell()); 
            uint32 startTime = now + 1*60;
            uint32 finishTime = now + 5*60 + 7*24*60*60;
            startProposal (m_SMVPlatformCode, m_SMVProposalCode,  
                           id, b.toCell(), startTime, finishTime);
        } else {
            _deployCommit(repoName, branchName, commitName, fullCommit, parent1, parent2);
            _deployDiff(repoName, diffName, branchName, diff);
            _deployBlob(repoName, commitName, blobName1, fullBlob1, prevSha1);
            _deployBlob(repoName, commitName, blobName2, fullBlob2, prevSha2);
        }
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
        Repository(repo).deployCommit{
            value: FEE_DEPLOY_COMMIT, bounce: true, flag: 2 
        }(tvm.pubkey(), branchName, commitName, fullCommit, parent1, parent2);
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
        string repoName,
        string name,
        string branch,
        string diff
    ) public view onlyOwner accept {
        _deployDiff(repoName, name, branch, diff);
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
    
    function deployBlob(
        string repoName,
        string commit,
        string blobName,
        string fullBlob,
        string prevSha
    ) public view onlyOwner accept {
        _deployBlob(repoName, commit, blobName, fullBlob, prevSha);
    }

    function _deployBlob(
        string repoName,
        string commit,
        string blobName,
        string fullBlob,
        string prevSha
    ) private view {
        address commitAddr = _buildCommitAddr(repoName, commit);
        /*  Commit(commitAddr).deployBlob{value: 2.8 ton}(tvm.pubkey(), blobName, fullBlob, prevSha); */
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deployBlob{
            value: 3 ton, bounce: true, flag: 2 
        }(tvm.pubkey(), commitAddr, blobName, fullBlob, prevSha);
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

    function getVersion() external view returns(string) {
        return version;
    }
}
