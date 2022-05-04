/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.58.0;

abstract contract Errors {
    uint constant ERR_NO_SALT = 100;
    uint constant ERR_SENDER_NOT_DAO = 102;
    uint constant ERR_ZERO_ROOT_KEY = 103;
    uint constant ERR_ZERO_ROOT_GOSH = 106;
    uint constant ERR_LOW_VALUE = 104;
    uint constant ERR_NOT_ROOT_REPO = 105;
    uint constant ERR_INVALID_SENDER = 107;
    uint constant ERR_LOW_BALANCE = 108;
    uint constant ERR_DOUBLE_MSG = 109;
    uint constant ERR_SENDER_NO_ALLOWED = 110;
    uint constant ERR_NO_DATA = 111;
    uint constant ERR_NOT_OWNER = 112;
    uint constant ERR_BRANCH_NOT_EXIST = 113;
    uint constant ERR_NOT_EMPTY_BRANCH = 114;
    uint constant ERR_BRANCH_EXIST = 115;
    uint constant ERR_TOO_MANY_PARENTS = 116;
    uint constant ERR_SECOND_CHANGE = 117;
    uint constant ERR_NOT_LAST_CHECK = 118;
    uint constant ERR_DONT_PASS_CHECK = 119;
}