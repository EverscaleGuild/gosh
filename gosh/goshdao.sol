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
import "goshwallet.sol";

/* Root contract of gosh */
contract GoshDao is Upgradable {
    string version = "0.0.1";
    TvmCell m_WalletCode;
    TvmCell m_WalletData;

    modifier onlyOwner {
        require(msg.pubkey() == tvm.pubkey(), 500);
        _;
    }

    constructor() public {
        tvm.accept();
    }

    function _composeWalletStateInit(uint256 pubkeyroot, uint256 pubkey, string name) internal view returns(TvmCell) {
        TvmBuilder b;
        b.store(address(this));
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_WalletCode, b.toCell());
        TvmCell _contractflex = tvm.buildStateInit({code: deployCode, contr: GoshWallet, varInit: {_nameRepo: name, _rootRepoPubkey: pubkeyroot, _pubkey: pubkey}});
        return _contractflex;
    }

    function deployWallet(uint256 pubkeyroot, uint256 pubkey, string name) public view {
        require(msg.value > 1 ton, 100);
        require(pubkey > 0, 101);
        tvm.accept();
        TvmCell s1 = _composeWalletStateInit(pubkeyroot, pubkey, name);
        new GoshWallet {stateInit: s1, value: 0.9 ton, wid: 0}();
    }

    function onCodeUpgrade() internal override {}

    //Setters

    function setWallet(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_WalletCode = code;
        m_WalletData = data;
    }

    //Getters

    function getAddrWallet(uint256 pubkeyroot, uint256 pubkey, string name) external view returns(address) {
        TvmCell s1 = _composeWalletStateInit(pubkeyroot, pubkey, name);
        return address.makeAddrStd(0, tvm.hash(s1));
    }

    function getWalletCode() external view returns(TvmCell) {
        return m_WalletCode;
    }
}
