// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IEscrow {

    event EscrowDeposit(uint loanId, address asset, uint assetTokenId);
    event EscrowRelease(uint loanId, address asset, uint assetTokenId, address to);

    function depositToEscrow(uint loanId, address asset, uint assetTokenId, address from) external;

    function releaseFromEscrow(uint loanId, address asset, uint assetTokenId, address to) external;

    function hasEscrowForLoan(uint loanId) external view returns (bool);

}