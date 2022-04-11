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
import "commit.sol";
import "snapshot.sol";
import "goshwallet.sol";
import "tag.sol";

/* Root contract of Repository */
struct Item {
        string key;
        address value;
        address snapshot;
}

contract Repository is Upgradable{
    string version = "0.0.1";
    uint256 _pubkey;
    TvmCell m_CommitCode;
    TvmCell m_CommitData;
    TvmCell m_BlobCode;
    TvmCell m_BlobData;
    TvmCell m_codeSnapshot;
    TvmCell m_dataSnapshot;
    TvmCell m_WalletCode;
    TvmCell m_WalletData;
    TvmCell m_codeTag;
    TvmCell m_dataTag;
    address _rootGosh;
    string _name;
    address _goshdao;
    mapping(string => Item) _Branches;

    modifier onlyOwner {
        require(msg.sender == _rootGosh, 500);
        _;
    }

    constructor(uint256 value0, string name, address goshdao) public {
        tvm.accept();
        _pubkey = value0;
        _rootGosh = msg.sender;
        _goshdao = goshdao;
        _name = name;
    }

    function deployNewSnapshot(string name) public onlyOwner {
        tvm.accept();
        TvmBuilder b;
        b.store(address(this));
        b.store(name);
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_codeSnapshot, b.toCell());
        TvmCell _contractflex = tvm.buildStateInit(deployCode, m_dataSnapshot);
        TvmCell s1 = tvm.insertPubkey(_contractflex, _pubkey);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        new Snapshot{stateInit:s1, value: 1 ton, wid: 0}(_pubkey, address(this), name);
        Snapshot(addr).setSnapshotCode{value: 0.1 ton, bounce: true, flag: 1}(m_codeSnapshot, m_dataSnapshot);
        Snapshot(addr).setSnapshot{value: 0.1 ton, bounce: true, flag: 1}("");
        _Branches["master"] = (Item("master", address.makeAddrNone(), addr));
    }

    function getSnapshotAddr(string name) private view returns(address) {
        TvmBuilder b;
        b.store(address(this));
        b.store(name);
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_codeSnapshot, b.toCell());
        TvmCell _contractflex = tvm.buildStateInit(deployCode, m_dataSnapshot);
        TvmCell s1 = tvm.insertPubkey(_contractflex, _pubkey);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        return addr;
    }

    function deployBranch(string newname, string fromname)  public {
        require(msg.value > 0.2 ton, 100);
        if (_Branches.exists(newname)) { return; }
        if (_Branches.exists(fromname) == false) { return; }
        _Branches[newname] = Item(newname, _Branches[fromname].value, getSnapshotAddr(newname));
    }

/*
    function deleteBranch(string name) public view {
        require(msg.value > 0.1 ton, 100);
        require(_Branches.exists(name), 102);
        Commit(_Branches[name].value).destroy{value: 0.1 ton, bounce: true, flag: 1}();
    }
    
    function deleteCommit(address parent, string nameBranch) public {
        require(msg.sender == _Branches[nameBranch].value,101);
        if (parent == address.makeAddrNone()) { delete _Branches[nameBranch]; return; }
        _Branches[nameBranch].value = parent;
        Commit(parent).destroy{value: 0.1 ton, bounce: true, flag: 1}();
    }
*/

    function _composeCommitStateInit(string _branch, string _commit) internal view returns(TvmCell) {
        TvmBuilder b;
        b.store(address(this));
        b.store(_branch);
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_CommitCode, b.toCell());
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Commit, varInit: {_nameCommit: _commit}});
        // return tvm.insertPubkey(stateInit, msg.pubkey());
        return stateInit;
    }
    
    function _composeWalletStateInit(uint256 pubkey) internal view returns(TvmCell) {
        TvmBuilder b;
        b.store(_goshdao);
        b.store(_rootGosh);
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_WalletCode, b.toCell());
        TvmCell _contractflex = tvm.buildStateInit({code: deployCode, contr: GoshWallet, varInit: {_rootRepoPubkey: _pubkey, _pubkey: pubkey}});
        return _contractflex;
    }

    function checkAccess(uint256 pubkey, address sender) internal view returns(bool) {
        TvmCell s1 = _composeWalletStateInit(pubkey);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        return addr == sender;
    }

    function deployCommit(uint256 pubkey, string nameBranch, string nameCommit, string fullCommit, address parent) public {
        tvm.accept();
        require(checkAccess(pubkey, msg.sender));
        require(_Branches.exists(nameBranch));
        require(_Branches[nameBranch].value == parent, 120);
        TvmCell s1 = _composeCommitStateInit(nameBranch, nameCommit);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        new Commit {stateInit: s1, value: 5 ton, wid: 0}(_goshdao, _rootGosh, _pubkey, _name, nameBranch, fullCommit, _Branches[nameBranch].value);
        Commit(addr).setBlob{value: 0.2 ton}(m_BlobCode, m_BlobData);
        Commit(addr).setWallet{value: 0.2 ton}(m_WalletCode, m_WalletData);
        _Branches[nameBranch] = Item(nameBranch, addr, _Branches[nameBranch].snapshot);
    }
    
    function deployTag(uint256 pubkey, string nametag, string nameCommit, address commit) public view {
        tvm.accept();
        require(checkAccess(pubkey, msg.sender));
        TvmBuilder b;
        b.store(address(this));
        b.store(nametag);
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_codeTag, b.toCell());
        TvmCell s1 = tvm.buildStateInit(deployCode, m_dataTag);
        new Tag {stateInit: s1, value: 5 ton, wid: 0}(nametag, nameCommit, commit);
    }

    function onCodeUpgrade() internal override {
    }

    //Setters
    
    function setTag(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_codeTag = code;
        m_dataTag = data;
    }

    function setCommit(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_CommitCode = code;
        m_CommitData = data;
    }
    
    function setWallet(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_WalletCode = code;
        m_WalletData = data;
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

    function getAddrBranch(string name) external view returns(Item) {
        return _Branches[name];
    }

    function getAllAddress() external view returns(Item[]) {
        Item[] AllBranches;
        for ((string _key, Item value) : _Branches) {
            _key;
            AllBranches.push(value);
        }
        return AllBranches;
    }

    function getCommitCode() external view returns(TvmCell) {
        return m_CommitCode;
    }

    function getGoshAdress() external view returns(address) {
        return _rootGosh;
    }
    
    function getRepoPubkey() external view returns(uint256) {
        return _pubkey;
    }

    function getCommitAddr(string nameBranch, string nameCommit) external view returns(address)  {
        require(_Branches.exists(nameBranch));
        TvmCell s1 = _composeCommitStateInit(nameBranch, nameCommit);
        return address.makeAddrStd(0, tvm.hash(s1));
    }
}
