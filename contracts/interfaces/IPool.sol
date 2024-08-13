// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IPool {

    event Deposit(address indexed account, uint amount);
    event Transfer(address indexed from, address indexed to, uint amount);
    event Withdraw(address indexed account, uint amount);
    event PoolCreated(address market, address paymentToken);

    function deposit(uint amount) external;

    function transfer(address from, address to, uint amount) external;

    function withdraw(uint amount) external;

    function balance(address account) external view returns (uint);
}