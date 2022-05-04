/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.54.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./libraries/GoshLib.sol";
import "goshwallet.sol";
/* Root contract of Blob */
contract Blob{
    string version = "0.1.0";
    string static _nameBlob;
    string _nameBranch;
    bool check = false;
    string _ipfsBlob;
    string _blob;
    uint256 _pubkey;
    string _prevSha;
    address _rootGosh;
    address _goshdao;
    address _rootCommit;
    TvmCell m_WalletCode;
    TvmCell m_WalletData;
    
    modifier onlyOwner { 
        require(msg.pubkey() == _pubkey, 500);
        _;
    }
    
    constructor(
        uint256 pubkey, 
        address commit,
        string nameBranch, 
        string blob,
        string ipfs, 
        string prevSha,
        address rootGosh,
        address goshdao,
        uint256 rootPubkey,
        TvmCell WalletCode,
        TvmCell WalletData) public {
        tvm.accept();
        // check whether _nameBlob is present
        // check whether salt is ok
        _ipfsBlob = ipfs;
        _rootCommit = commit;
        _pubkey = rootPubkey;
        _rootGosh = rootGosh;
        _goshdao = goshdao;
        _nameBranch = nameBranch;
        _blob = blob;
        _prevSha = prevSha;
        m_WalletCode = WalletCode;
        m_WalletData = WalletData;
        require(checkAccess(pubkey, msg.sender));
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

/*    
    function destroy(address addr) public onlyOwner {
        selfdestruct(addr);
    }
*/
    
    //Setters

    // need we change the field ipfs
    
    //Getters
    function getNameBlob() external view returns(string) {
        return _nameBlob;
    }
    
    function getprevSha() external view returns(string) {
        return _prevSha;
    }

    function getNameBranch() external view returns(string) {
        return _nameBranch;
    }
    
    function getCommitAdress() external view returns(address) {
        return _rootCommit;
    }
    
    function getBlob() external view returns(string sha, address commit, string content, string ipfs) {
        return (_nameBlob, _rootCommit, _blob, _ipfsBlob);
    }

    function getVersion() external view returns(string) {
        return version;
    }
}
