/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.58.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./modifiers/modifiers.sol";
import "gosh.sol";
import "goshwallet.sol";
import "./libraries/GoshLib.sol";

/* Root contract of gosh */
contract DaoCreator is Modifiers{
    string version = "0.1.0";
    address _gosh;
    TvmCell m_WalletCode;
    TvmCell m_WalletData;
    TvmCell m_codeDao;
    TvmCell m_dataDao;

    uint128 constant FEE_DEPLOY_DAO = 100 ton;

    constructor(
        address gosh, 
        TvmCell WalletCode,
        TvmCell WalletData,
        TvmCell codeDao,
        TvmCell dataDao) public onlyOwner {
        tvm.accept();
        _gosh = gosh;
        m_WalletCode = WalletCode;
        m_WalletData = WalletData;
        m_codeDao = codeDao;
        m_dataDao = dataDao;
    }

    function deployDao(
        string name, 
        uint256 root_pubkey) public view accept {
        Gosh(_gosh).deployDao{
            value: FEE_DEPLOY_DAO, bounce: true, flag: 2
        }(name, root_pubkey);
    }
    
    /*
    function get_lastGoshDao public view returns (address) {
        return  _lastGoshDao;
    }
    */

    function sendMoney(uint256 pubkeyroot, uint256 pubkey, address goshdao, uint128 value) public view {
        TvmCell s1 = _composeWalletStateInit(pubkeyroot, pubkey, goshdao);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        require(addr == msg.sender, ERR_SENDER_NO_ALLOWED);
        tvm.accept();
        addr.transfer(value);
    }
    
    function sendMoneyDao(string name, uint128 value) public view {
        TvmCell s1 = _composeDaoStateInit(name);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        require(addr == msg.sender, ERR_SENDER_NO_ALLOWED);
        tvm.accept();
        addr.transfer(value);
    }
    
    function _composeDaoStateInit(string name) internal view returns(TvmCell) {
        TvmBuilder b;
        b.store(_gosh);
        b.store(name);
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_codeDao, b.toCell());
        return tvm.buildStateInit(deployCode, m_dataDao);
    }
    
    function _composeWalletStateInit(uint256 pubkeyroot, uint256 pubkey, address goshdao) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildWalletCode(m_WalletCode, pubkey, version);
        TvmCell _contractflex = tvm.buildStateInit({
            code: deployCode,
            pubkey: pubkey,
            contr: GoshWallet,
            varInit: {_rootRepoPubkey: pubkeyroot, _rootgosh : _gosh, _goshdao: goshdao}
        });
        return _contractflex;
    }
    

    //Setters

    //Getters

    function getAddrRootGosh() external view returns(address) {
        return _gosh;
    }

    function getVersion() external view returns(string) {
        return version;
    }
}
