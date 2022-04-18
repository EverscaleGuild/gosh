/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.54.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "commit.sol";
import "snapshot.sol";
import "goshwallet.sol";
import "tag.sol";
import "./libraries/GoshLib.sol";

/* Root contract of Repository */
struct Item {
        string key;
        address value;
        address[] snapshot;
}

contract Repository {
    string version = "0.1.0";
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
    string static _name;
    address _goshdao;
    mapping(string => Item) _Branches;

    modifier onlyOwner {
        require(msg.sender == _rootGosh, 500);
        _;
    }

    constructor(
        uint256 value0, 
        string name, 
        address goshdao,
        TvmCell CommitCode,
        TvmCell CommitData,
        TvmCell BlobCode,
        TvmCell BlobData,
        TvmCell codeSnapshot,
        TvmCell dataSnapshot,
        TvmCell WalletCode,
        TvmCell WalletData,
        TvmCell codeTag,
        TvmCell dataTag
        ) public {
        tvm.accept();
        _pubkey = value0;
        _rootGosh = msg.sender;
        _goshdao = goshdao;
        _name = name;
        m_CommitCode = CommitCode;
        m_CommitData = CommitData;
        m_BlobCode = BlobCode;
        m_BlobData = BlobData;
        m_codeSnapshot = codeSnapshot;
        m_dataSnapshot = dataSnapshot;
        m_WalletCode = WalletCode;
        m_WalletData = WalletData;
        m_codeTag = codeTag;
        m_dataTag = dataTag;
        address[] files;
        _Branches["main"] = Item("main", address.makeAddrNone(), files);
    }

    function deployNewSnapshot(string name, string branch, string diff) private {
        tvm.accept();
        TvmCell deployCode = GoshLib.buildSnapshotCode(m_codeSnapshot, address(this), version);
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Snapshot, varInit: {NameOfFile: branch + "/" + name}});
        address addr = address.makeAddrStd(0, tvm.hash(stateInit));
        new Snapshot{stateInit:stateInit, value: 1 ton, wid: 0}(_pubkey, address(this), m_codeSnapshot, m_dataSnapshot, branch, name);
        Snapshot(addr).setSnapshot{value: 0.1 ton, bounce: true, flag: 1}(diff);
        _Branches[branch].snapshot.push(addr);
    }
    
    function deployDiff(uint256 pubkey, string name, string branch, string diff) public {
        require(_Branches.exists(branch), 110);
        require(checkAccess(pubkey, msg.sender));
        address addr = getSnapshotAddr(branch + "/" + name);
        for (address a : _Branches[branch].snapshot) {
            if (a == addr) { Snapshot(addr).setSnapshot{value: 0.1 ton, bounce: true, flag: 1}(diff); return; }
        }
        deployNewSnapshot(name,  branch, diff);
    }

    function getSnapshotAddr(string name) private view returns(address) {
        TvmCell deployCode = GoshLib.buildSnapshotCode(m_codeSnapshot, address(this), version);
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Snapshot, varInit: {NameOfFile: name}});
        address addr = address.makeAddrStd(0, tvm.hash(stateInit));
        return addr;
    }

    function deployBranch(uint256 pubkey, string newname, string fromname)  public {
        require(msg.value > _Branches[fromname].snapshot.length * 1.5 ton, 100);
        require(checkAccess(pubkey, msg.sender));
        if (_Branches.exists(newname)) { return; }
        if (_Branches.exists(fromname) == false) { return; }
        address[] files;
        _Branches[newname] = Item(newname, _Branches[fromname].value, files);
        this.copySnapshot(0, fromname, newname);
    }
    
    function copySnapshot(uint32 index, string fromname, string newname)  public view {
        require(msg.sender == address(this));
        require(index <= _Branches[fromname].snapshot.length - 1);
        Snapshot(_Branches[fromname].snapshot[index]).deployNewSnapshot{value: 1.4 ton, bounce: true, flag: 1}(newname);
        this.copySnapshot(index + 1, fromname, newname);
    }
    
    function addSnapshot(address addr, string oldbranch, string newbranch) public {
        require(msg.value > 0.5 ton, 105);
        for (address a : _Branches[oldbranch].snapshot) {
            if (a == msg.sender) { _Branches[newbranch].snapshot.push(addr); return; }
        }
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

    function _composeCommitStateInit(string _commit) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildCommitCode(m_CommitCode, address(this), version);
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Commit, varInit: {_nameCommit: _commit}});
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

    function deployCommit(uint256 pubkey, string nameBranch, string nameCommit, string fullCommit, address parent1, address parent2) public {
        tvm.accept();
        require(checkAccess(pubkey, msg.sender));
        require(_Branches.exists(nameBranch));
        require(_Branches[nameBranch].value == parent1, 120);
        TvmCell s1 = _composeCommitStateInit(nameCommit);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        new Commit {stateInit: s1, value: 2 ton, wid: 0}(
            _goshdao, _rootGosh, _pubkey, _name, nameBranch, fullCommit, _Branches[nameBranch].value, parent2, m_BlobCode, m_BlobData, m_WalletCode, m_WalletData);
        _Branches[nameBranch] = Item(nameBranch, addr, _Branches[nameBranch].snapshot);
    }
    
    function deployTag(uint256 pubkey, string nametag, string nameCommit, address commit) public view {
        tvm.accept();
        require(checkAccess(pubkey, msg.sender));
        TvmCell deployCode = GoshLib.buildTagCode(m_codeTag, address(this), nametag, version);
        TvmCell s1 = tvm.buildStateInit(deployCode, m_dataTag);
        new Tag {stateInit: s1, value: 5 ton, wid: 0}(nametag, nameCommit, commit);
    }

    //Setters
    
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
    
    function getName() external view returns(string) {
        return _name;
    }

    function getCommitAddr(string nameBranch, string nameCommit) external view returns(address)  {
        require(_Branches.exists(nameBranch));
        TvmCell s1 = _composeCommitStateInit(nameCommit);
        return address.makeAddrStd(0, tvm.hash(s1));
    }
    
    function getSnapAddr(string branch, string name) external view returns(address)  {
        return getSnapshotAddr(branch + "/" + name);
    }

    function getVersion() external view returns(string) {
        return version;
    }
}
