/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.58.0;

abstract contract Errors {
    string constant versionErrors = "0.2.0";
    uint constant ERR_NO_SALT = 200;
    uint constant ERR_SENDER_NOT_DAO = 202;
    uint constant ERR_ZERO_ROOT_KEY = 203;
    uint constant ERR_ZERO_ROOT_GOSH = 206;
    uint constant ERR_LOW_VALUE = 204;
    uint constant ERR_NOT_ROOT_REPO = 205;
    uint constant ERR_INVALID_SENDER = 207;
    uint constant ERR_LOW_BALANCE = 208;
    uint constant ERR_DOUBLE_MSG = 209;
    uint constant ERR_SENDER_NO_ALLOWED = 210;
    uint constant ERR_NO_DATA = 211;
    uint constant ERR_NOT_OWNER = 212;
    uint constant ERR_BRANCH_NOT_EXIST = 213;
    uint constant ERR_NOT_EMPTY_BRANCH = 214;
    uint constant ERR_BRANCH_EXIST = 215;
    uint constant ERR_TOO_MANY_PARENTS = 216;
    uint constant ERR_SECOND_CHANGE = 217;
    uint constant ERR_NOT_LAST_CHECK = 218;
    uint constant ERR_DONT_PASS_CHECK = 219;
    uint constant ERR_WRONG_COMMIT_ADDR = 220;
    uint constant ERR_NEED_PUBKEY = 221;
    uint constant ERR_WRONG_NAME = 222;
}
