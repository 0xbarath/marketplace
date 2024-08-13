// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IPriceOracle {

    function getAssetPrice(address assetContract, uint assetTokenId) external view returns (uint);

    function isSupportedAsset(address assetContract) external view returns (bool);
}


