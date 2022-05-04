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
import "./libraries/GoshLib.sol";
import "goshwallet.sol";

/* Root contract of tag */
contract Tag {
    string version = "0.1.0";
    string static _nametag;
    string _nameCommit;
    string _content;
    address _commit;
    uint256 _pubkey;
    address _rootGosh;
    address _goshdao;
    TvmCell m_WalletCode;
    TvmCell m_WalletData;
    
    constructor(
        uint256 value0, 
        uint256 value1,
        string nameCommit, 
        address commit, 
        string content,
        address gosh,
        address goshdao,
        TvmCell WalletCode,
        TvmCell WalletData) public {
        tvm.accept();
        _rootGosh = gosh;
        _goshdao = goshdao;
        _nameCommit = nameCommit;
        _commit = commit;
        _content = content;
        m_WalletCode = WalletCode;
        m_WalletData = WalletData;
        _pubkey = value0;
        require(checkAccess(value1, msg.sender));
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
    
    function destroy(uint256 pubkey) public {
        require(checkAccess(pubkey, msg.sender));
        selfdestruct(msg.sender);
    }
    
    //Getters
    function getCommit() external view returns(address) {
        return _commit;
    }
    
    function getContent() external view returns(string) {
        return _content;
    }

    function getVersion() external view returns(string) {
        return version;
    }
}
