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
import "./modifiers/modifiers.sol";

/* Root contract of Repository */
struct Item {
        string key;
        address value;
}

contract Repository is Modifiers{
    string constant version = "0.2.0";
    uint256 _pubkey;
    TvmCell m_CommitCode;
    TvmCell m_BlobCode;
    TvmCell m_WalletCode;
    TvmCell m_codeTag;
    address _rootGosh;
    string static _name;
    address _goshdao;
    string _head;
    mapping(string => Item) _Branches;

    constructor(
        uint256 value0, 
        string name, 
        address goshdao,
        TvmCell CommitCode,
        TvmCell BlobCode,
        TvmCell WalletCode,
        TvmCell codeTag
        ) public {
        require(_name != "", ERR_NO_DATA);
        tvm.accept();
        _pubkey = value0;
        _rootGosh = msg.sender;
        _goshdao = goshdao;
        _name = name;
        m_CommitCode = CommitCode;
        m_BlobCode = BlobCode;
        m_WalletCode = WalletCode;
        m_codeTag = codeTag;
        TvmCell s1 = _composeCommitStateInit("0000000000000000000000000000000000000000");
        _Branches["main"] = Item("main", address.makeAddrStd(0, tvm.hash(s1)));
        _head = "main";
    }

    function deployBranch(uint256 pubkey, string newname, string fromname)  public minValue(0.5 ton) {
        require(checkAccess(pubkey, msg.sender), ERR_SENDER_NO_ALLOWED);
        tvm.accept();
        require(_Branches.exists(newname) == false, ERR_BRANCH_EXIST);
        require(_Branches.exists(fromname), ERR_BRANCH_NOT_EXIST);
        _Branches[newname] = Item(newname, _Branches[fromname].value);
    }
    
    function deleteBranch(uint256 pubkey, string name) public minValue(0.3 ton){
        tvm.accept();
        require(_Branches.exists(name), ERR_BRANCH_NOT_EXIST);
        require(checkAccess(pubkey, msg.sender), ERR_SENDER_NO_ALLOWED);
        delete _Branches[name]; 
    }

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

    function setCommit(string nameBranch, address commit) public senderIs(_Branches[nameBranch].value) {
        require(_Branches.exists(nameBranch), ERR_BRANCH_NOT_EXIST);
        tvm.accept();
        _Branches[nameBranch] = Item(nameBranch, commit);
    }
    
    function setHEAD(uint256 pubkey, string nameBranch) public {
        require(checkAccess(pubkey, msg.sender),ERR_SENDER_NO_ALLOWED);
        require(_Branches.exists(nameBranch), ERR_BRANCH_NOT_EXIST);
        tvm.accept();
        _head = nameBranch;
    }

    function _composeBlobStateInit(string nameBlob) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildBlobCode(
            m_BlobCode, address(this), version
        );
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Blob, varInit: {_nameBlob: nameBlob}});
        return stateInit;
    }
    
    function destroy() public onlyOwner {
        selfdestruct(msg.sender);
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
    
    function getTagCode() external view returns(TvmCell) {
        return GoshLib.buildTagCode(m_codeTag, address(this), version);
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

    function getCommitAddr(string nameCommit) external view returns(address)  {
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
