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
import "snapshot.sol";
import "repository.sol";

contract Snapshot {
    string version = "0.1.0";
    uint256 pubkey;
    address _rootRepo;
    string _snapshot;
    TvmCell m_codeSnapshot;
    TvmCell m_dataSnapshot;
    string static NameOfFile;
    string _name; 
    string _branch;

    modifier onlyOwner {
        require(msg.sender == _rootRepo, 500);
        _;
    }

    constructor(uint256 value0, address rootrepo, TvmCell codeSnapshot, TvmCell dataSnapshot, string branch, string name) public {
        tvm.accept();
        pubkey = value0;
        _rootRepo = rootrepo;
        _snapshot = "";
        m_codeSnapshot = codeSnapshot;
        m_dataSnapshot = dataSnapshot;
        _branch = branch;
        _name = name;
    }
    
    function deployNewSnapshot(string newbranch) public view onlyOwner {
        require(msg.value > 1.3 ton, 100);
        tvm.accept();
        TvmCell deployCode = GoshLib.buildSnapshotCode(m_codeSnapshot, _rootRepo, version);
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Snapshot, varInit: {NameOfFile: newbranch + "/" + _name}});
        address addr = address.makeAddrStd(0, tvm.hash(stateInit));
        new Snapshot{stateInit:stateInit, value: 0.5 ton, wid: 0}(pubkey, _rootRepo, m_codeSnapshot, m_dataSnapshot, newbranch, _name);
        Snapshot(addr).setSnapshotSelf{value: 0.1 ton, bounce: true, flag: 1}(_snapshot, _branch);
        Repository(_rootRepo).addSnapshot{value: 0.6 ton, bounce: true, flag: 1}(addr, _branch, newbranch);
    }
    
    function getSnapshotAddr(string name) private view returns(address) {
        TvmCell deployCode = GoshLib.buildSnapshotCode(m_codeSnapshot, _rootRepo, version);
        TvmCell stateInit = tvm.buildStateInit({code: deployCode, contr: Snapshot, varInit: {NameOfFile: name}});
        address addr = address.makeAddrStd(0, tvm.hash(stateInit));
        return addr;
    }

    //Setters
    
    function setSnapshot(string snaphot) public onlyOwner {
        tvm.accept();
        _snapshot = snaphot;
    }

    function setSnapshotSelf(string snaphot, string branch) public {
        require(msg.sender == getSnapshotAddr(branch + "/" + _name));
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

    function getVersion() external view returns(string) {
        return version;
    }
}
