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

abstract contract ARepository {
    function deleteCommit(address parent, string nameBranch) external {}
}

/* Root contract of Commit */
contract Commit {
    string version = "0.0.1";
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
    address _parent;
    address _rootGosh;
    uint128 _num = 1;
    bool _isFinish = false;

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

    constructor(address goshdao, address rootGosh, uint256 value0, string nameRepo, string nameBranch, string commit, address parent) public {
        _parent = parent;
        tvm.accept();
        _name = nameRepo;
        _rootGosh = rootGosh;
        _goshdao = goshdao;
        _pubkey = value0;
        _rootRepo = msg.sender;
        _nameBranch = nameBranch;
        _commit = commit;
    }
    
    function _composeBlobStateInit(string nameBlob) internal view returns(TvmCell) {
        TvmBuilder b;
        b.store(address(this));
        b.store(_nameBranch);
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_BlobCode, b.toCell());
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Blob, varInit: {_nameBlob: nameBlob}});
        //return tvm.insertPubkey(stateInit, pubkey);
        return stateInit;
    }
    
    function _composeWalletStateInit(uint256 pubkey) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildWalletCode(m_WalletCode, _goshdao, _rootGosh, version);
        TvmCell _contractflex = tvm.buildStateInit({
            code: deployCode,
            pubkey: pubkey,
            contr: GoshWallet,
            varInit: {_rootRepoPubkey: _pubkey}
        });
        return _contractflex;
    }

    function checkAccess(uint256 pubkey, address sender) internal view returns(bool) {
        TvmCell s1 = _composeWalletStateInit(pubkey);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        return addr == sender;
    }

    function deployBlob(uint256 pubkey, string nameBlob, string fullBlob) public {
        tvm.accept();
        require(checkAccess(pubkey, msg.sender));
        TvmCell s1 = _composeBlobStateInit(nameBlob);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        new Blob{stateInit: s1, value: 1 ton, wid: 0}(pubkey, _nameBranch, fullBlob);
        _blob.push(addr);
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
    function setBlob(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();

        m_BlobCode = code;
        m_BlobData = data;
    }

    function setStatus(bool status) public  onlyOwner {
        tvm.accept();
        _isFinish = status;
    }
    
    function setWallet(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_WalletCode = code;
        m_WalletData = data;
    }

    //Getters
    function getBlobs() external view returns(address[]) {
        return _blob;
    }

     function getParent() external view returns(address) {
        return _parent;
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
        address parent,
        string content
    ) {
        return (_rootRepo, _nameBranch, _nameCommit, _parent, _commit);
    }

    function getBlobAddr(string nameBlob) external view returns(address) {
        TvmCell s1 = _composeBlobStateInit(nameBlob);
        return address.makeAddrStd(0, tvm.hash(s1));
    }

    function getStatus() external view returns(bool) {
        return _isFinish;
    }
}
