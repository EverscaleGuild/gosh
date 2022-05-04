/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.54.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./modifiers/modifiers.sol";
import "goshwallet.sol";
import "daocreator.sol";
import "./libraries/GoshLib.sol";
import "../smv/TokenRootOwner.sol";

/* Root contract of gosh */
contract GoshDao is Modifiers, TokenRootOwner {
    string version = "0.1.0";
    address _creator;
    TvmCell m_WalletCode;
    TvmCell m_WalletData;    
    TvmCell m_RepositoryCode;
    TvmCell m_RepositoryData;
    TvmCell m_CommitCode;
    TvmCell m_CommitData;
    TvmCell m_BlobCode;
    TvmCell m_BlobData;
    TvmCell m_TagCode;
    TvmCell m_TagData;
    address _rootgosh;
    string _nameDao;
    address[] _wallets;
    
    //added for SMV
    TvmCell m_TokenLockerCode;
    TvmCell m_SMVPlatformCode;
    TvmCell m_SMVClientCode;
    TvmCell m_SMVProposalCode;

    TvmCell m_TokenRootCode;
    TvmCell m_TokenWalletCode;
    address public _rootTokenRoot;
    address public _lastAccountAddress;

    constructor(
        address rootgosh, 
        address creator,
        uint256 pubkey, 
        string name, 
        TvmCell CommitCode,
        TvmCell CommitData,
        TvmCell BlobCode,
        TvmCell BlobData,
        TvmCell RepositoryCode,
        TvmCell RepositoryData,
        TvmCell WalletCode, 
        TvmCell WalletData,
        TvmCell TagCode,
        TvmCell TagData,
        /////////////////////
        TvmCell TokenLockerCode,
        TvmCell SMVPlatformCode,
        TvmCell SMVClientCode,
        TvmCell SMVProposalCode,
        TvmCell TokenRootCode,
        TvmCell TokenWalletCode
        ////////////////////////
        /* address initialSupplyTo,
        uint128 initialSupply,
        uint128 deployWalletValue,
        bool mintDisabled,
        bool burnByRootDisabled,
        bool burnPaused,
        address remainingGasTo,
        uint256 randomNonce */ ) public onlyOwner TokenRootOwner (TokenRootCode, TokenWalletCode) {
        tvm.accept();
        _creator = creator;
        _rootgosh = rootgosh;
        _rootpubkey = pubkey;
        _nameDao = name;
        m_WalletCode = WalletCode;
        m_WalletData = WalletData;
        m_RepositoryCode = RepositoryCode;
        m_RepositoryData = RepositoryData;
        m_CommitCode = CommitCode;
        m_CommitData = CommitData;
        m_BlobCode = BlobCode;
        m_BlobData = BlobData;
        m_TagCode = TagCode;
        m_TagData = TagData;
        /////
        m_TokenLockerCode = TokenLockerCode;
        m_SMVPlatformCode = SMVPlatformCode;

        TvmBuilder b;
        b.store(address(this));
        m_SMVProposalCode = tvm.setCodeSalt(SMVProposalCode, b.toCell());
        m_SMVClientCode = tvm.setCodeSalt(SMVClientCode, b.toCell());

        m_TokenRootCode = TokenRootCode;
        m_TokenWalletCode = TokenWalletCode;
        getMoney();
        ///////////////////////////////////////
        _rootTokenRoot = _deployRoot (address.makeAddrStd(0,0), 0, 0, false, false, true, address.makeAddrStd(0,0), now);
    }
    
    function getMoney() private {
        if (address(this).balance > 10000 ton) { return; }
        tvm.accept();
        DaoCreator(_creator).sendMoneyDao{value : 0.2 ton}(_nameDao, 10000 ton);
    }

    function _composeWalletStateInit(uint256 pubkey) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildWalletCode(m_WalletCode, pubkey, version);
        TvmCell _contractflex = tvm.buildStateInit({
            code: deployCode,
            pubkey: pubkey,
            contr: GoshWallet,
            varInit: {_rootRepoPubkey: _rootpubkey, _rootgosh : _rootgosh, _goshdao: address(this)}
        });
        return _contractflex;
    }

    function deployWallet(uint256 pubkey) public onlyOwnerPubkey(_rootpubkey) {
        tvm.accept();
        TvmCell s1 = _composeWalletStateInit(pubkey);
        _lastAccountAddress = address.makeAddrStd(0, tvm.hash(s1));
        _wallets.push(_lastAccountAddress);
        new GoshWallet {
            stateInit: s1, value: 60 ton, wid: 0
        }(_creator, m_CommitCode, m_CommitData, 
            m_BlobCode, m_BlobData, 
            m_RepositoryCode, m_RepositoryData,
            m_WalletCode, m_WalletData,
            m_TagCode, m_TagData,
            m_TokenLockerCode, m_SMVPlatformCode,
            m_SMVClientCode, m_SMVProposalCode, _rootTokenRoot);
        getMoney();
    }

    //Setters

    //Getters

    function getAddrWallet(uint256 pubkey) external view returns(address) {
        TvmCell s1 = _composeWalletStateInit(pubkey);
        return address.makeAddrStd(0, tvm.hash(s1));
    }

    function getWalletCode() external view returns(TvmCell) {
        return m_WalletCode;
    }

    function getProposalCode() external view returns(TvmCell) {
        return m_SMVProposalCode;
    }

    function getClientCode() external view returns(TvmCell) {
        return m_SMVClientCode;
    }
    
    function getWallets() external view returns(address[]) {
        return _wallets;
    }

    function getNameDao() external view returns(string) {
        return _nameDao;
    }

    function getRootPubkey() external view returns(uint256) {
        return _rootpubkey;
    }

    function getVersion() external view returns(string) {
        return version;
    }
}
