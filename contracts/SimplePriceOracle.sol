// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SimplePriceOracle is IPriceOracle, AccessControl {

    event PriceUpdated(address assetContract, uint newValue);
    event SupportedAssetUpdated(address assetContract, bool value);

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    mapping(address => bool) private supportedAssets;
    mapping(address => uint) private prices;

    constructor(address operator) {
        require(operator != address(0), "invalid operator");
        _grantRole(DEFAULT_ADMIN_ROLE, operator);
        _grantRole(ORACLE_ROLE, operator);
    }

    function updateSupportedAsset(address assetContract, bool value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(assetContract != address(0), "invalid asset");
        supportedAssets[assetContract] = value;
        emit SupportedAssetUpdated(assetContract, value);
    }

    function setAssetPrice(address assetContract, uint newValue) external onlyRole(ORACLE_ROLE) {
        require(newValue > 0, "invalid value");
        require(isSupportedAsset(assetContract), "Asset not supported");
        prices[assetContract] = newValue;
        emit PriceUpdated(assetContract, newValue);
    }

    function getAssetPrice(address assetContract) external view override returns (uint) {
        require(isSupportedAsset(assetContract), "Asset not supported");
        return prices[assetContract];
    }

    function isSupportedAsset(address assetContract) public view override returns (bool) {
        return supportedAssets[assetContract];
    }
}