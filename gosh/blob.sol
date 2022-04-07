/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.54.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

/* Root contract of Blob */
contract Blob{
    string version = "0.0.1";
    address _rootCommit;
    string static _nameBlob;
    string _nameBranch;
    bool check = false;
    string _blob;
    uint256 _pubkey;
    
    modifier onlyOwner {
        bool checkOwn = false;
        if (msg.sender == _rootCommit) { checkOwn = true; }    
        if (msg.pubkey() == _pubkey) { checkOwn = true; }
        require(msg.sender == _rootCommit, 500);
        _;
    }
    
    constructor(uint256 pubkey, string nameBranch, string blob) public {
        tvm.accept();
        _pubkey = pubkey;
        _rootCommit = msg.sender;
        _nameBranch = nameBranch;
        _blob = blob;
    }    
    
    function destroy(address addr) public onlyOwner {
        selfdestruct(addr);
    }
    
    //Setters
    
    //Getters
    function getNameBlob() external view returns(string) {
        return _nameBlob;
    }

    function getNameBranch() external view returns(string) {
        return _nameBranch;
    }
    
    function getCommitAdress() external view returns(address) {
        return _rootCommit;
    }
    
    function getBlob() external view returns(string sha, address commit, string content) {
        return (_nameBlob, _rootCommit, _blob);
    }
}
