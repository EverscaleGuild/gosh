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

/* Root contract of Commit */
contract Commit {
    string version = "0.0.1";
    uint256 pubkey;
    address _rootRepo;
    string static _nameCommit;
    string _nameBranch;
    string _commit;
    bool check = false;
    address[] _blob;
    TvmCell m_BlobCode;
    TvmCell m_BlobData;
    address _parent;
    modifier onlyOwner {
        bool checkOwn = false;
        if (msg.sender == _rootRepo) { checkOwn = true; }    
        if (msg.pubkey() == pubkey) { checkOwn = true; }
        require(checkOwn ,500);
        _;
    }
    
    modifier onlyFirst {
        require(check == false,600);
        _;
    }
    
    constructor(uint256 value0, string nameBranch, string commit, address parent) public {
        _parent = parent;
        tvm.accept();
        pubkey = value0;
        _rootRepo = msg.sender;
        _nameBranch = nameBranch;
        _commit = commit;
    }
    
    function deployBlob(string nameBlob, string fullblob) public onlyOwner {
        tvm.accept();
        TvmBuilder b;
        b.store(address(this));
        b.store(_nameBranch);
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_BlobCode, b.toCell());
        TvmCell _contractflex = tvm.buildStateInit({code: deployCode, contr: Blob, varInit: {_nameBlob: nameBlob}});
        TvmCell s1 = tvm.insertPubkey(_contractflex, msg.pubkey());
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        new Blob{stateInit:s1, value: 1 ton, wid: 0} (_nameBranch, fullblob);
        _blob.push(addr);
    }

    //Setters
    function setBlob(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_BlobCode = code;
        m_BlobData = data;
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

    function getCommit() external view returns (address, string, string, address, string) {
        return (_rootRepo, _nameBranch, _nameCommit, _parent, _commit);
    }

    function getBlobAddr(string nameBlob) external view returns(address) {
        tvm.accept();
        TvmBuilder b;
        b.store(address(this));
        b.store(_nameBranch);
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_BlobCode, b.toCell());
        TvmCell _contractflex = tvm.buildStateInit({code: deployCode, contr: Blob, varInit: {_nameBlob: nameBlob}});
        TvmCell s1 = tvm.insertPubkey(_contractflex, msg.pubkey());
        address addr = address.makeAddrStd(0, tvm.hash(s1));
        return addr;
    }
}
