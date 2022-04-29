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
import "goshwallet.sol";
import "tag.sol";
import "blob.sol";
import "./libraries/GoshLib.sol";

/* Root contract of Repository */
struct Item {
        string key;
        address value;
}

contract Repository {
    string version = "0.1.0";
    uint256 _pubkey;
    TvmCell m_CommitCode;
    TvmCell m_CommitData;
    TvmCell m_BlobCode;
    TvmCell m_BlobData;
    TvmCell m_WalletCode;
    TvmCell m_WalletData;
    TvmCell m_codeTag;
    TvmCell m_dataTag;
    address _rootGosh;
    string static _name;
    address _goshdao;
    string _head;
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
        m_WalletCode = WalletCode;
        m_WalletData = WalletData;
        m_codeTag = codeTag;
        m_dataTag = dataTag;
        _Branches["main"] = Item("main", address.makeAddrNone());
        _head = "main";
    }

    function deployBranch(uint256 pubkey, string newname, string fromname)  public {
        require(msg.value > 0.5 ton, 100);
        require(checkAccess(pubkey, msg.sender));
        if (_Branches.exists(newname)) { return; }
        if (_Branches.exists(fromname) == false) { return; }
        _Branches[newname] = Item(newname, _Branches[fromname].value);
    }
    
    function deleteBranch(uint256 pubkey, string name) public {
        require(msg.value > 0.3 ton, 100);
        tvm.accept();
        require(_Branches.exists(name), 102);
        require(checkAccess(pubkey, msg.sender));
        delete _Branches[name]; 
    }
/*    
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

    function setCommit(uint256 pubkey, string nameBranch, address commit) public {
        tvm.accept();
        require(checkAccess(pubkey, msg.sender),101);
        require(_Branches.exists(nameBranch), 102);
        _Branches[nameBranch] = Item(nameBranch, commit);
    }
    
    function setHEAD(uint256 pubkey, string nameBranch) public {
        tvm.accept();
        require(checkAccess(pubkey, msg.sender),101);
        require(_Branches.exists(nameBranch), 102);
        _head = nameBranch;
    }
    
    function deployTag(uint256 pubkey, string nametag, string nameCommit, address commit) public view {
        tvm.accept();
        require(checkAccess(pubkey, msg.sender));
        TvmCell deployCode = GoshLib.buildTagCode(m_codeTag, address(this), nametag, version);
        TvmCell s1 = tvm.buildStateInit(deployCode, m_dataTag);
        new Tag {stateInit: s1, value: 5 ton, wid: 0}(nametag, nameCommit, commit);
    }

    function _composeBlobStateInit(string nameBlob) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildBlobCode(
            m_BlobCode, address(this), version
        );
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Blob, varInit: {_nameBlob: nameBlob}});
        //return tvm.insertPubkey(stateInit, pubkey);
        return stateInit;
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
    
    function getHEAD() external view returns(string) {
        return _head;
    }

    function getCommitAddr(string nameBranch, string nameCommit) external view returns(address)  {
        require(_Branches.exists(nameBranch));
        TvmCell s1 = _composeCommitStateInit(nameCommit);
        return address.makeAddrStd(0, tvm.hash(s1));
    }
    
    function getBlobAddr(string nameBlob) external view returns(address) {
        TvmCell s1 = _composeBlobStateInit(nameBlob);
        return address.makeAddrStd(0, tvm.hash(s1));
    }

    function getVersion() external view returns(string) {
        return version;
    }
}
