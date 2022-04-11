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

/* Root contract of tag */
contract Tag {
    string _nametag;
    string _nameCommit;
    address _commit;
    
    constructor(string nametag, string nameCommit, address commit) public {
        tvm.accept();
        _nametag = nametag;
        _nameCommit = nameCommit;
        _commit = commit;
    }
    
    //Getters
    function getCommit() external view returns(address) {
        return _commit;
    }
}
