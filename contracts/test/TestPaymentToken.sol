// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestPaymentToken is ERC20 {

    constructor() ERC20("Test Payment Token", "TPT") {}

    function mint(address to, uint amount) public {
        _mint(to, amount);
    }
}