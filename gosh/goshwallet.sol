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
import "gosh.sol";
import "repository.sol";
import "commit.sol";

/* Root contract of gosh */
contract GoshWallet is Upgradable {
    string version = "0.0.1";
    address constant _rootgosh = address(0xf8b999fd3a21c0880a52ca50724b730534fd4dd5c2279686aa9816c242267796); //Need to update after deploy gosh
    string static _nameRepo;
    uint256 static _rootRepoPubkey;
    uint256 static _pubkey;

    modifier onlyOwner {
        require(msg.pubkey() == _pubkey, 500);
        _;
    }

    constructor() public {
        tvm.accept();
    }

    function deployRepository() public view {
        require(msg.value > 3 ton, 100);
        require(msg.pubkey() == _rootRepoPubkey, 121);
        tvm.accept();
        Gosh(_rootgosh).deployRepository{value: 2.8 ton}(_rootRepoPubkey, _nameRepo);
    }
    
    function deployCommit(address repo, string nameBranch, string nameCommit, string fullCommit, address parent) public view onlyOwner {
        tvm.accept();
        Repository(repo).deployCommit{value: 2.8 ton}(_pubkey, nameBranch, nameCommit, fullCommit, parent);
    }
    
    function deployBlob(address commit, string nameBlob, string fullBlob) public view onlyOwner {
        tvm.accept();
        Commit(commit).deployBlob{value: 2.8 ton}(_pubkey, nameBlob, fullBlob);
    }

    function onCodeUpgrade() internal override {}

    //Setters

    //Getters

    function getAddrRootGosh() external pure returns(address) {
        return _rootgosh;
    }

    function getRepositoryName() external view returns(string) {
        return _nameRepo;
    }

    function getRootPubkey() external view returns(uint256) {
        return _rootRepoPubkey;
    }

    function getWalletPubkey() external view returns(uint256) {
        return _pubkey;
    }
}
