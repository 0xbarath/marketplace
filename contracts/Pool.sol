// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IPool} from "./interfaces/IPool.sol";
import {ILoanMarketplace} from "./interfaces/ILoanMarketplace.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Pool is IPool {
    using SafeERC20 for IERC20;

    address public market;
    address public paymentToken;
    mapping(address => uint) private _balances;

    constructor(address _market) {
        require(_market != address(0), "Invalid market address");
        market = _market;
        paymentToken = ILoanMarketplace(_market).getPaymentToken();
        emit PoolCreated(_market, paymentToken);
    }

    modifier onlyMarket() {
        require(msg.sender == market, "Only market can call this function");
        _;
    }

    function deposit(uint amount) external override {
        require(amount > 0, "Amount must be greater than 0");
        _balances[msg.sender] += amount;
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, amount);
    }

    function transfer(address from, address to, uint amount) onlyMarket external override {
        require(_balances[from] >= amount, "Insufficient balance");
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function withdraw(uint amount) external override {
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        _balances[msg.sender] -= amount;
        IERC20(paymentToken).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    function balance(address account) external view override returns (uint) {
        return _balances[account];
    }
}