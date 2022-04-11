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
    TvmCell m_RepositoryCode;
    TvmCell m_RepositoryData;
    TvmCell m_CommitCode;
    TvmCell m_CommitData;
    TvmCell m_BlobCode;
    TvmCell m_BlobData;
    address _rootgosh;
    uint256 _rootpubkey;
    string _nameDao;
 
    modifier onlyOwner {
        require(msg.pubkey() == _rootpubkey, 500);
        _;
    }

    constructor(address rootgosh, uint256 pubkey, string name) public {
        tvm.accept();
        _rootgosh = rootgosh;
        _rootpubkey = pubkey;
        _nameDao = name;
    }

    function _composeWalletStateInit(uint256 pubkeyroot, uint256 pubkey) internal view returns(TvmCell) {
        TvmBuilder b;
        b.store(address(this));
        b.store(_rootgosh);
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_WalletCode, b.toCell());
        TvmCell _contractflex = tvm.buildStateInit({code: deployCode, contr: GoshWallet, varInit: {_rootRepoPubkey: pubkeyroot, _pubkey: pubkey}});
        return _contractflex;
    }

    function deployWallet(uint256 pubkeyroot, uint256 pubkey) public view {
        require(msg.value > 1 ton, 100);
        require(pubkey > 0, 101);
        tvm.accept();
        TvmCell s1 = _composeWalletStateInit(pubkeyroot, pubkey);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        new GoshWallet {stateInit: s1, value: 0.9 ton, wid: 0}(_rootgosh);
        GoshWallet(addr).setCommit{value: 0.2 ton}(m_CommitCode, m_CommitData);
        GoshWallet(addr).setBlob{value: 0.2 ton}(m_BlobCode, m_BlobData);
        GoshWallet(addr).setRepository{value: 0.2 ton}(m_RepositoryCode, m_RepositoryData);
    }

    function onCodeUpgrade() internal override {}

    //Setters
    
    function setRepository(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_RepositoryCode = code;
        m_RepositoryData = data;
    }

    function setCommit(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_CommitCode = code;
        m_CommitData = data;
    }

    function setBlob(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_BlobCode = code;
        m_BlobData = data;
    }


    function setWallet(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_WalletCode = code;
        m_WalletData = data;
    }

    //Getters

    function getAddrWallet(uint256 pubkeyroot, uint256 pubkey) external view returns(address) {
        TvmCell s1 = _composeWalletStateInit(pubkeyroot, pubkey);
        return address.makeAddrStd(0, tvm.hash(s1));
    }

    function getWalletCode() external view returns(TvmCell) {
        return m_WalletCode;
    }

    function getNameDao() external view returns(string) {
        return _nameDao;
    }

}
