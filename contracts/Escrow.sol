// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IEscrow} from "./interfaces/IEscrow.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


contract Escrow is IEscrow, Ownable {
    using SafeERC20 for IERC20;

    mapping(uint => mapping(address => mapping(uint => uint))) private _escrowBalances;

    constructor(address marketplace) Ownable(marketplace) {
        require(marketplace != address(0), "Invalid marketplace address");
    }

    function depositToEscrow(uint loanId, address asset, uint assetTokenId, address from) external onlyOwner override {
        require(from != address(0), "Invalid from address");
        require(asset != address(0), "Invalid asset address");
        require(_escrowBalances[loanId][asset][assetTokenId] == 0, "Already in escrow");
        _escrowBalances[loanId][asset][assetTokenId] = 1;
        IERC721(asset).safeTransferFrom(from, address(this), assetTokenId);
        emit EscrowDeposit( loanId, asset, assetTokenId);
    }

    function releaseFromEscrow(uint loanId, address asset, uint assetTokenId, address to) external onlyOwner override {
        require(_escrowBalances[loanId][asset][assetTokenId] == 1, "No escrow balance");
        _escrowBalances[loanId][asset][assetTokenId] = 0;
        IERC721(asset).safeTransferFrom(address(this), to, assetTokenId);
        emit EscrowRelease(loanId, asset, assetTokenId, to);
    }

    function hasEscrowForLoan(uint loanId) external view override returns (bool) {
        return _escrowBalances[loanId][msg.sender][0] == 1;
    }
}
