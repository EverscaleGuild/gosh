/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.54.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "blob.sol";
import "goshwallet.sol";
import "commit.sol";
import "repository.sol";
import "./libraries/GoshLib.sol";

abstract contract ARepository {
    function deleteCommit(address parent, string nameBranch) external {}
}

/* Root contract of Commit */
contract Commit {
    string version = "0.1.0";
    uint256 _pubkey;
    address _rootRepo;
    address _goshdao;
    string static _nameCommit;
    string _nameBranch;
    string _commit;
    string _name;
    bool check = false;
    address[] _blob;
    TvmCell m_BlobCode;
    TvmCell m_BlobData;
    TvmCell m_WalletCode;
    TvmCell m_WalletData;
    TvmCell m_CommitCode;
    TvmCell m_CommitData;
    address _parent1;
    address _parent2;
    address _rootGosh;
    uint128 _num = 1;

    modifier onlyOwner {
        bool checkOwn = false;
        if (msg.sender == _rootRepo) { checkOwn = true; }
        if (msg.pubkey() == _pubkey) { checkOwn = true; }
        require(checkOwn, 500);
        _;
    }

    modifier onlyFirst {
        require(check == false, 600);
        _;
    }

    constructor(address goshdao, 
        address rootGosh, 
        uint256 value0,
        uint256 value1, 
        string nameRepo, 
        string nameBranch, 
        string commit, 
        address parent1,
        address parent2,
        TvmCell BlobCode,
        TvmCell BlobData,
        TvmCell WalletCode,
        TvmCell WalletData,
        TvmCell CommitCode,
        TvmCell CommitData) public {
        tvm.accept();
        _parent1 = parent1;
        _parent2 = parent2;
        _name = nameRepo;
        _rootGosh = rootGosh;
        _goshdao = goshdao;
        _pubkey = value0;
        _rootRepo = msg.sender;
        _nameBranch = nameBranch;
        _commit = commit;
        m_BlobCode = BlobCode;
        m_BlobData = BlobData;
        m_WalletCode = WalletCode;
        m_WalletData = WalletData;
        m_CommitCode = CommitCode;
        m_CommitData = CommitData;
        require(checkAccess(value1, msg.sender));
    }
    
    function _composeBlobStateInit(string nameBlob) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildBlobCode(
            m_BlobCode, _rootRepo, version
        );
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Blob, varInit: {_nameBlob: nameBlob}});
        //return tvm.insertPubkey(stateInit, pubkey);
        return stateInit;
    }
    
    function _composeWalletStateInit(uint256 pubkey) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildWalletCode(m_WalletCode, pubkey, version);
        TvmCell _contractflex = tvm.buildStateInit({
            code: deployCode,
            pubkey: pubkey,
            contr: GoshWallet,
            varInit: {_rootRepoPubkey: _pubkey, _rootgosh : _rootGosh, _goshdao: _goshdao}
        });
        return _contractflex;
    }

    function checkAccess(uint256 pubkey, address sender) internal view returns(bool) {
        TvmCell s1 = _composeWalletStateInit(pubkey);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        return addr == sender;
    }
    
    function WalletCheckCommit(
        uint256 pubkey, 
        string branchName,
        uint128 number,
        address newC) public {
        require(checkAccess(pubkey, msg.sender), 100);
        require(address(this) == newC, 101);
        require(number > 0, 102);
        tvm.accept();
        number -= 1;
        Commit(_parent1).CommitCheckCommit{value: 0.3 ton * number + 0.3 ton, bounce: true, flag: 2}(_nameCommit, branchName, number, newC); 
    }
    
    function CommitCheckCommit(
        string nameCommit,
        string branchName,
        uint128 number,
        address newC) public {
        require(_buildCommitAddr(nameCommit) == msg.sender, 100);
        tvm.accept();
        if (number == 0) {
            Repository(_rootRepo).setCommit{value: 0.3 ton, bounce: true, flag: 2}(branchName, newC);
        }
        else {
            number -= 1;
            if (_parent1 == address.makeAddrNone()) { 
                require(number == 0, 201);
                Repository(_rootRepo).setFirstCommit{value: 0.3 ton, bounce: true, flag: 2}(_nameCommit, branchName, newC);
            }
            Commit(_parent1).CommitCheckCommit{value: 0.3 ton * number + 0.3 ton, bounce: true, flag: 2}(_nameCommit, branchName, number, newC); 
        }
    }

    function setBlobs(uint256 pubkey, address[] blobs) public {
        require(checkAccess(pubkey, msg.sender));
        tvm.accept();
        _blob = blobs;
    }    
/*    
    function destroy() public onlyOwner {
        tvm.accept();
        _num -= 1;
        if (_num == 0) { this.destroyAll(); }
        else { ARepository(_rootRepo).deleteCommit{value: 0.1 ton, bounce: true, flag: 1}(address.makeAddrNone(), _nameBranch); }
    }
    
    function destroyAll() public {
        require(msg.sender == address(this));
        tvm.accept();
        if (_blob.length == 0) { 
            ARepository(_rootRepo).deleteCommit{value: 0.1 ton, bounce: true, flag: 1}(_parent, _nameBranch);
            selfdestruct(_rootRepo); 
            return;
        }
        Blob(_blob[_blob.length - 1]).destroy{value: 0.1 ton, bounce: true, flag: 1}(_rootRepo);
        _blob.pop();
        this.destroyAll();
    }
*/

    //Setters
    
    //Getters
    
    function _buildCommitAddr(
        string commit
    ) private view returns(address) {
        TvmCell deployCode = GoshLib.buildCommitCode(m_CommitCode, _rootRepo, version);
        TvmCell state = tvm.buildStateInit({
            code: deployCode, 
            contr: Commit,
            varInit: {_nameCommit: commit}
        });
        return address(tvm.hash(state));
    }
    
    function getBlobs() external view returns(address[]) {
        return _blob;
    }

     function getParent() external view returns(address, address) {
        return (_parent1, _parent2);
    }

    function getNameCommit() external view returns(string) {
        return _nameCommit;
    }

    function getNameBranch() external view returns(string) {
        return _nameBranch;
    }

    function getRepoAdress() external view returns(address) {
        return _rootRepo;
    }

    function getCommit() external view returns (
        address repo,
        string branch,
        string sha,
        address parent1,
        address parent2,
        string content
    ) {
        return (_rootRepo, _nameBranch, _nameCommit, _parent1, _parent2, _commit);
    }

    function getBlobAddr(string nameBlob) external view returns(address) {
        TvmCell s1 = _composeBlobStateInit(nameBlob);
        return address.makeAddrStd(0, tvm.hash(s1));
    }

    function getVersion() external view returns(string) {
        return version;
    }
}
