/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.58.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
import "modifiers.sol";
import "Upgradable.sol";

contract GoshConfig is Modifiers, Upgradable {

    struct GlobalConfig {
        address goshAddr;
    }

    GlobalConfig _config;

    constructor(address goshAddr) public onlyOwner accept {
        _config.goshAddr = goshAddr;
    }

    //
    // Setters
    //

    function setGoshAddress(address goshAddr) public onlyOwner accept {
        _config.goshAddr = goshAddr;
    }

    //
    // Getters
    //

    function get() public view responsible returns (GlobalConfig config) {
        config = _config;
    }

    //
    // Upgradable
    //

    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }
}