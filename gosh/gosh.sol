/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.54.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "repository.sol";
import "goshdao.sol";

/* Root contract of gosh */
contract Gosh {
    string version = "0.1.0";
    address _creator;
    TvmCell m_RepositoryCode;
    TvmCell m_RepositoryData;
    TvmCell m_CommitCode;
    TvmCell m_CommitData;
    TvmCell m_BlobCode;
    TvmCell m_BlobData;
    TvmCell m_WalletCode;
    TvmCell m_WalletData;
    TvmCell m_codeDao;
    TvmCell m_dataDao;
    TvmCell m_codeTag;
    TvmCell m_dataTag;

    //SMV
    TvmCell m_TokenLockerCode;
    TvmCell m_SMVPlatformCode;
    TvmCell m_SMVClientCode;
    TvmCell m_SMVProposalCode;

    //TIP3
    TvmCell m_TokenRootCode;
    TvmCell m_TokenWalletCode;

    address public _lastGoshDao;

    modifier onlyOwner {
        require(msg.pubkey() == tvm.pubkey(), 500);
        _;
    }

    constructor(address creator) public {
        tvm.accept();
        _creator = creator;
    }

    function _composeRepoStateInit(string name, address goshdao) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildRepositoryCode(
            m_RepositoryCode, address(this), goshdao, version
        );
        return tvm.buildStateInit({
            code: deployCode, 
            contr: Repository,
            varInit: {_name: name}
        });
    }
    
    function _composeWalletStateInit(uint256 pubkey, uint256 rootpubkey, address dao) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildWalletCode(m_WalletCode, pubkey, version);
        TvmCell _contractflex = tvm.buildStateInit({
            code: deployCode,
            pubkey: pubkey,
            contr: GoshWallet,
            varInit: {_rootRepoPubkey: rootpubkey, _rootgosh : address(this), _goshdao: dao}
        });
        return _contractflex;
    }

    function checkAccess(uint256 pubkey, uint256 rootpubkey, address sender, address dao) internal view returns(bool) {
        TvmCell s1 = _composeWalletStateInit(pubkey, rootpubkey, dao);
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        return addr == sender;
    }

    function deployRepository(uint256 pubkey, uint256 rootpubkey, string name, address goshdao) public view {
        require(msg.value > 3 ton, 100);
        require(rootpubkey > 0, 101);
        require(checkAccess(pubkey, rootpubkey, msg.sender, goshdao));
        tvm.accept();
        TvmCell s1 = _composeRepoStateInit(name, goshdao);
        new Repository {stateInit: s1, value: 0.4 ton, wid: 0}(
            rootpubkey, name, goshdao, m_CommitCode, m_CommitData, m_BlobCode, m_BlobData, m_WalletCode, m_WalletData, m_codeTag, m_dataTag);
    }
    
    function _composeDaoStateInit(string name) internal view returns(TvmCell) {
        TvmBuilder b;
        b.store(address(this));
        b.store(name);
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_codeDao, b.toCell());
        return tvm.buildStateInit(deployCode, m_dataDao);
    }
    
    function deployDao(string name, uint256 root_pubkey) public {
        require(msg.value > 3 ton, 100);
        require(root_pubkey > 0, 101);
        tvm.accept();
        TvmCell s1 = _composeDaoStateInit(name);
        _lastGoshDao = new GoshDao {stateInit: s1, value: 90 ton, wid: 0}(
            address(this), _creator, root_pubkey, name, m_CommitCode, m_CommitData, m_BlobCode, m_BlobData, m_RepositoryCode, m_RepositoryData, m_WalletCode, m_WalletData, m_codeTag, m_dataTag,
            m_TokenLockerCode, m_SMVPlatformCode, m_SMVClientCode, m_SMVProposalCode, m_TokenRootCode, m_TokenWalletCode);
    }

    //Setters
    
    //SMV

    /* TvmCell m_TokenLockerCode;
    TvmCell m_SMVPlatformCode;
    TvmCell m_SMVClientCode;
    TvmCell m_SMVProposalCode; */

    function setTokenRoot(TvmCell code, TvmCell /* data */) public  onlyOwner {
        tvm.accept();
        m_TokenRootCode = code;
       /*  m_RepositoryData = data; */
    }

    function setTokenWallet(TvmCell code, TvmCell /* data */) public  onlyOwner {
        tvm.accept();
        m_TokenWalletCode = code;
       /*  m_RepositoryData = data; */
    }

    function setTokenLocker(TvmCell code, TvmCell /* data */) public  onlyOwner {
        tvm.accept();
        m_TokenLockerCode = code;
       /*  m_RepositoryData = data; */
    }

    function setSMVPlatform(TvmCell code, TvmCell /* data */) public  onlyOwner {
        tvm.accept();
        m_SMVPlatformCode = code;
        /* m_RepositoryData = data; */
    }

    function setSMVClient(TvmCell code, TvmCell /* data */) public  onlyOwner {
        tvm.accept();
        m_SMVClientCode = code;
       /*  m_RepositoryData = data; */
    }

    function setSMVProposal(TvmCell code, TvmCell /* data */) public  onlyOwner {
        tvm.accept();
        m_SMVProposalCode = code;
        /* m_RepositoryData = data; */
    }

    //////////////////////////////////////////////////////////////////////


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
    
    function setDao(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_codeDao = code;
        m_dataDao = data;
    }
    
    function setTag(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_codeTag = code;
        m_dataTag = data;
    }

    //Getters

    function getAddrRepository(string name, string dao) external view returns(address) {
        TvmCell s1 = _composeRepoStateInit(name, address.makeAddrStd(0, tvm.hash(_composeDaoStateInit(dao))));
        return address.makeAddrStd(0, tvm.hash(s1));
    }
    
    function getAddrDao(string name) external view returns(address) {
        TvmCell s1 = _composeDaoStateInit(name);
        return address.makeAddrStd(0, tvm.hash(s1));
    }
    
    function getRepoDaoCode(address dao) external view returns(TvmCell) {
        return GoshLib.buildRepositoryCode(
            m_RepositoryCode, address(this), dao, version
        );
    }
    
    function getDaoWalletCode(uint256 pubkey) external view returns(TvmCell) {
        return GoshLib.buildWalletCode(m_WalletCode, pubkey, version);
    }

    function getSMVProposalCode() external view returns(TvmCell) {
        return m_SMVProposalCode;
    }
    
    function getSMVPlatformCode() external view returns(TvmCell) {
        return m_SMVPlatformCode;
    }

    function getSMVClientCode() external view returns(TvmCell) {
        return m_SMVClientCode;
    }

    function getRepositoryCode() external view returns(TvmCell) {
        return m_RepositoryCode;
    }

    function getCommitCode() external view returns(TvmCell) {
        return m_CommitCode;
    }

    function getBlobCode() external view returns(TvmCell) {
        return m_BlobCode;
    }
    
    function getTagCode() external view returns(TvmCell) {
        return m_codeTag;
    }

    function getVersion() external view returns(string) {
        return version;
    }
}
