/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.54.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./libraries/GoshLib.sol";

/* Snapshot contract of Branch */
abstract contract ASnapshot {
    constructor(uint256 value0, address rootrepo, string nameBranch, TvmCell code, TvmCell data) public {}
    function setSnapshot(string snaphot) public {}
}

contract Snapshot {
    string version = "0.0.1";
    uint256 pubkey;
    address _rootRepo;
    string _snapshot;
    TvmCell m_codeSnapshot;
    TvmCell m_dataSnapshot;
    string static NameOfFile;

    modifier onlyOwner {
        bool check = false;
        if (msg.sender == _rootRepo) { check = true; }
        if (msg.pubkey() == pubkey) { check = true; }
        require(check ,500);
        _;
    }

    constructor(uint256 value0, address rootrepo, TvmCell codeSnapshot, TvmCell dataSnapshot) public {
        tvm.accept();
        pubkey = value0;
        _rootRepo = rootrepo;
        _snapshot = "";
        m_codeSnapshot = codeSnapshot;
        m_dataSnapshot = dataSnapshot;
    }

    function deployNewSnapshot(string name) public view onlyOwner {
        require(msg.value > 1.3 ton, 100);
        optional(uint32) startOpt = NameOfFile.find(byte("/"));
        require(startOpt.hasValue(), 666);
        uint32 start = startOpt.get();
        string lastPart = NameOfFile.substr(start, NameOfFile.byteLength() - start);
        name += lastPart;
        TvmCell deployCode = GoshLib.buildSnapshotCode(m_codeSnapshot, _rootRepo, version);
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Snapshot, varInit: {NameOfFile: name}});
        address addr = address.makeAddrStd(0, tvm.hash(stateInit));
        TvmCell payload = tvm.encodeBody(ASnapshot, pubkey, _rootRepo, name, m_codeSnapshot, m_dataSnapshot);
        addr.transfer({stateInit: stateInit, body: payload, value: 1 ton});
        ASnapshot(addr).setSnapshot{value: 0.1 ton, bounce: true, flag: 1}(_snapshot);
    }

    //Setters

    function setSnapshot(string snaphot) public onlyOwner {
        tvm.accept();
        _snapshot = snaphot;
    }

    //Getters
    function getSnapshot() external view returns(string) {
        return _snapshot;
    }

    function getName() external view returns(string) {
        return NameOfFile;
    }

    function getBranchAdress() external view returns(address) {
        return _rootRepo;
    }
}
