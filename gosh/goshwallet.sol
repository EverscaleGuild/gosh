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

import "./modifiers/modifiers.sol";
import "gosh.sol";
import "repository.sol";
import "commit.sol";
import "tag.sol";
import "daocreator.sol";
import "./libraries/GoshLib.sol";
import "../smv/SMVAccount.sol";
import "../smv/Libraries/SMVConstants.sol";
import "../smv/LockerPlatform.sol";

abstract contract Object {
    function destroy() external {}
}


contract GoshWallet is Modifiers, SMVAccount, IVotingResultRecipient {
    uint128 constant FEE_DEPLOY_REPO = 4 ton;
    uint128 constant FEE_DEPLOY_COMMIT = 4 ton;

    // mapping to store hashes of inbound messages;
    /* mapping(uint256 => uint32) m_messages; */
    // Each transaction is limited by gas, so we must limit count of iteration in loop.
    /* uint8 constant MAX_CLEANUP_MSGS = 20;

    modifier saveMsg() {
        m_messages[m_lastMsg.msgHash] = m_lastMsg.expireAt;
        gc();
        _;
    }

    struct LastMsg {
        uint32 expireAt;
        uint256 msgHash;
    } */

    string constant version = "0.2.0";
    address _creator;
    uint256 static _rootRepoPubkey;
    address static _rootgosh;
    address static _goshdao;
    bool _flag = false;
    TvmCell m_RepositoryCode;
    TvmCell m_CommitCode;
    TvmCell m_BlobCode;
    TvmCell m_WalletCode;
    TvmCell m_TagCode;
    //LastMsg m_lastMsg;

    TvmCell m_SMVPlatformCode;
    TvmCell m_SMVClientCode;
    TvmCell m_SMVProposalCode;

    constructor(
        address creator,
        TvmCell commitCode,
        TvmCell blobCode,
        TvmCell repositoryCode,
        TvmCell WalletCode, 
        TvmCell TagCode,
         //added for SMV
        TvmCell lockerCode,
        TvmCell platformCode,
        TvmCell clientCode,
        TvmCell proposalCode,
        address _tip3Root
    ) public SMVAccount(lockerCode, tvm.hash(platformCode), platformCode.depth(),
                        tvm.hash(clientCode), clientCode.depth(), tvm.hash(proposalCode),
                        proposalCode.depth(), _tip3Root
    ) {
        require(tvm.pubkey() != 0, ERR_NEED_PUBKEY);
        _creator = creator;
        m_CommitCode = commitCode;
        m_BlobCode = blobCode;
        m_RepositoryCode = repositoryCode;
        m_WalletCode = WalletCode;
        m_TagCode = TagCode;
        ///////////////////
        m_SMVPlatformCode = platformCode;
        m_SMVClientCode = clientCode;
        m_SMVProposalCode = proposalCode;
        getMoney();
    }

    function destroyObject(address obj) public onlyOwner accept {
        Object(obj).destroy{value : 0.2 ton}();
    }

    function _composeCommitStateInit(string _commit, address repo) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildCommitCode(m_CommitCode, repo, version);
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Commit, varInit: {_nameCommit: _commit}});
        return stateInit;
    }

    function getMoney() private {
        if (_flag == true) { return; }
        _flag = true;
        if (address(this).balance > 20000 ton) { return; }
        DaoCreator(_creator).sendMoney{value : 0.2 ton}(_rootRepoPubkey, tvm.pubkey(), _goshdao, 10000 ton);
    }

    function deployRepository(string nameRepo) public onlyOwner accept saveMsg {
        address[] emptyArr;
        _deployCommit(nameRepo, "main", "0000000000000000000000000000000000000000", "", emptyArr);
        Gosh(_rootgosh).deployRepository{
            value: FEE_DEPLOY_REPO, bounce: true
        }(tvm.pubkey(), _rootRepoPubkey, nameRepo, _goshdao);
        getMoney();
    }

    function deployCommit(
        string repoName,
        string branchName,
        string commitName,
        string fullCommit,
        address[] parents
    ) public onlyOwner accept saveMsg {
        require(parents.length <= 7, ERR_TOO_MANY_PARENTS);
        _deployCommit(repoName, branchName, commitName, fullCommit, parents);
    }

    function _deployCommit(
        string repoName,
        string branchName,
        string commitName,
        string fullCommit,
        address[] parents
    ) internal {
        address repo = _buildRepositoryAddr(repoName);
        TvmCell s1 = _composeCommitStateInit(commitName, repo);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        new Commit {stateInit: s1, value: 20 ton, wid: 0}(
            _goshdao, _rootgosh, _rootRepoPubkey, tvm.pubkey(), repoName, branchName, fullCommit, parents, repo, m_BlobCode, m_WalletCode, m_CommitCode);
        getMoney();
    }

    //SMV configuration
    uint32 constant SETCOMMIT_PROPOSAL_START_AFTER = 1 minutes;
    uint32 constant SETCOMMIT_PROPOSAL_DURATION = 1 weeks;
    uint256 constant SETCOMMIT_PROPOSAL_KIND = 1;

    function isProposalNeeded(
        string repoName,
        string branchName,
        address branchcommit,
        string commit
    ) internal pure returns(bool) {
       return ((branchName == "main") || (branchName == "master"));
    }

    function _setCommit(
        string repoName,
        string branchName,
        address branchcommit,
        string commit
    ) internal view {
        address repo = _buildRepositoryAddr(repoName);
        TvmCell s0 = _composeCommitStateInit(commit, repo);
        address addrC = address.makeAddrStd(0, tvm.hash(s0));
        Commit(addrC).WalletCheckCommit{value: 0.5 ton, bounce: true}(tvm.pubkey(), branchName, branchcommit, addrC);
    }

    function setCommit(
        string repoName,
        string branchName,
        address branchcommit,
        string commit
    ) public onlyOwner {
        require(!isProposalNeeded (repoName, branchName, branchcommit, commit), SMVErrors.error_proposol_is_needed);
        tvm.accept();
        _saveMsg();

        _setCommit(repoName, branchName, branchcommit, commit);
        getMoney();
    }

    function startProposalForSetCommit(
        string repoName,
        string branchName,
        address branchcommit,
        string commit
    ) public onlyOwner {
        require(isProposalNeeded(repoName, branchName, branchcommit, commit), SMVErrors.error_proposol_is_not_needed);
        tvm.accept();
        _saveMsg();

        TvmBuilder proposalBuilder;
        uint256 proposalKind = SETCOMMIT_PROPOSAL_KIND;
        proposalBuilder.store(proposalKind, repoName, branchName, branchcommit, commit);
        TvmCell c = proposalBuilder.toCell();
        uint256 prop_id = tvm.hash(c); 
        uint32 startTime = now + SETCOMMIT_PROPOSAL_START_AFTER;
        uint32 finishTime = now + SETCOMMIT_PROPOSAL_START_AFTER + SETCOMMIT_PROPOSAL_DURATION;
        startProposal (m_SMVPlatformCode, m_SMVProposalCode, prop_id, c, startTime, finishTime);

        getMoney();
    }

    function _composeBlobStateInit(string nameBlob, address repo) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildBlobCode(m_BlobCode, repo, version);
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
        string ipfsBlob,
        string prevSha, 
        uint8 flags
    ) public onlyOwner accept saveMsg {
        _deployBlob(repoName, commit, branch, blobName, fullBlob, ipfsBlob, prevSha, flags);
    }

    function _deployBlob(
        string repoName,
        string commit,
        string branch,
        string blobName,
        string fullBlob,
        string ipfsBlob,
        string prevSha,
        uint8 flags
    ) internal {
        address repo = _buildRepositoryAddr(repoName);
        TvmCell s0 = _composeCommitStateInit(commit, repo);
        address addrC = address.makeAddrStd(0, tvm.hash(s0));
        TvmCell s1 = _composeBlobStateInit(blobName, repo);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        new Blob{
            stateInit: s1, value: 1 ton, wid: 0
        }(tvm.pubkey(), addrC, branch, fullBlob, ipfsBlob, prevSha, flags, _rootgosh, _goshdao, _rootRepoPubkey, m_WalletCode);
        getMoney();
    }

    function setBlob(
        string repoName,
        string commitName,
        address[] blobs
    ) public onlyOwner accept saveMsg {
        address repo = _buildRepositoryAddr(repoName);
        TvmCell s1 = _composeCommitStateInit(commitName, repo);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        Commit(addr).setBlobs{value: 1 ton, bounce: true}(tvm.pubkey(), blobs);
        getMoney();
    }

    function setHEAD(
        string repoName,
        string branchName
    ) public onlyOwner accept saveMsg {
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).setHEAD{value: 1 ton, bounce: true}(tvm.pubkey(), branchName);
        getMoney();
    }

    function tryProposalResult(address proposal) public view onlyOwner accept saveMsg{
        ISMVProposal(proposal).isCompleted{
            value: SMVConstants.VOTING_COMPLETION_FEE + SMVConstants.EPSILON_FEE
        }();
    }

    function calcClientAddress(uint256 _platform_id, address _tokenLocker) internal view returns(uint256) {
        TvmCell dataCell = tvm.buildDataInit({
            contr: LockerPlatform,
            varInit: {
                tokenLocker: _tokenLocker,
                platform_id: _platform_id
            }
        });
        uint256 dataHash = tvm.hash(dataCell);
        uint16 dataDepth = dataCell.depth();

        uint256 add_std_address = tvm.stateInitHash(
            tvm.hash(m_SMVPlatformCode),
            dataHash,
            m_SMVPlatformCode.depth(),
            dataDepth
        );
        return add_std_address;
    }

    function sendMoney(address repo, string commit) public {
        TvmCell s0 = _composeCommitStateInit(commit, repo);
        address addr = address.makeAddrStd(0, tvm.hash(s0));
        require(addr == msg.sender, ERR_SENDER_NO_ALLOWED);
        tvm.accept();
        addr.transfer(100 ton);
        getMoney();
    }

    modifier check_client(uint256 _platform_id, address _tokenLocker) {
        uint256 expected = calcClientAddress (_platform_id, _tokenLocker);
        require ( msg.sender.value == expected, SMVErrors.error_not_my_client) ;
        _ ;
    }

    function isCompletedCallback(
        uint256 _platform_id,
        address _tokenLocker,
        optional(bool) res,
        TvmCell propData
    ) external override check_client(_platform_id, _tokenLocker) {
        //for tests
        lastVoteResult = res;
        ////////////////////

        if (res.hasValue() && res.get()) {
            TvmSlice s = propData.toSlice();
            uint256 kind = s.decode(uint256);
            if (kind == SETCOMMIT_PROPOSAL_KIND) {
                (string repoName, string branchName, address branchcommit, string commit) =
                    s.decode(string, string, address, string);
                _setCommit(repoName, branchName, branchcommit, commit);
            }
        }
    }

    function deployBranch(
        string repoName,
        string newName,
        string fromName
    ) public view onlyOwner accept saveMsg {
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deployBranch{
            value: 1 ton, bounce: true
        }(tvm.pubkey(), newName, fromName);
    }

    function deleteBranch(
        string repoName,
        string Name
    ) public view onlyOwner accept saveMsg {
        address repo = _buildRepositoryAddr(repoName);
        Repository(repo).deleteBranch{
            value: 1 ton, bounce: true
        }(tvm.pubkey(), Name);
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
        string content,
        address commit
    ) public view onlyOwner accept saveMsg {
        address repo = _buildRepositoryAddr(repoName);
        TvmCell deployCode = GoshLib.buildTagCode(m_TagCode, repo, version);
        TvmCell s1 = tvm.buildStateInit({code: deployCode, contr: Tag, varInit: {_nametag: nametag}});
        new Tag{
            stateInit: s1, value: 5 ton, wid: 0
        }(_rootRepoPubkey, tvm.pubkey(), nameCommit, commit, content, _rootgosh, _goshdao, m_WalletCode);
    }

    function deleteTag(string repoName, string nametag) public view onlyOwner accept saveMsg {
        address repo = _buildRepositoryAddr(repoName);
        TvmCell deployCode = GoshLib.buildTagCode(m_TagCode, repo, version);
        TvmCell s1 = tvm.buildStateInit({code: deployCode, contr: Tag, varInit: {_nametag: nametag}});
        address tagaddr = address.makeAddrStd(0, tvm.hash(s1));
        Tag(tagaddr).destroy{
            value: 0.1 ton, bounce: true
        }(tvm.pubkey());
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

    function afterSignatureCheck(TvmSlice body, TvmCell message) private inline returns (TvmSlice) {
        // load and drop message timestamp (uint64)
        (, uint32 expireAt) = body.decode(uint64, uint32);
        require(expireAt > now, 57);
        uint256 msgHash = tvm.hash(message);
        require(!m_messages.exists(msgHash), ERR_DOUBLE_MSG);
        m_lastMsg = LastMsg(expireAt, msgHash);
        return body;
    }

    /* function gc() private {
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
    } */

    /* fallback/receive */
    receive() external {
        if (msg.sender == _creator) {
            _flag = false;
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
            varInit: { _name: name }
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
            varInit: { _nameCommit: commit }
        });
        return address(tvm.hash(state));
    }

    function getVersion() external view returns(string) {
        return version;
    }
}
