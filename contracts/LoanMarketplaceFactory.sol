// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Escrow.sol";
import "./Pool.sol";

contract LoanMarketplaceFactory {

    event VaultProxyDeployed(address impl, address proxy);
    address immutable private EscrowImpl = address(new Escrow());
    address immutable private PoolImpl = address(new Pool());

    function deployEscrow(address marketplace) external returns(Escrow escrow) {
        address escrowAddress = deployProxy(EscrowImpl,
            abi.encodeWithSelector(
                Escrow.initialize.selector,
                marketplace),
            keccak256(abi.encode(marketplace)));
        escrow = Escrow(escrowAddress);
        emit VaultProxyDeployed(EscrowImpl, escrowAddress);
    }

    function deployPool(address marketplace, address paymentToken) external returns(Pool pool) {
        address poolAddress = deployProxy(PoolImpl,
            abi.encodeWithSelector(
                Pool.initialize.selector,
                marketplace,
                paymentToken),
            keccak256(abi.encode(marketplace, paymentToken)));
        pool = Pool(poolAddress);
        emit VaultProxyDeployed(PoolImpl, poolAddress);
    }

    function deployProxy(address implementation, bytes memory data, bytes32 salt) internal returns (address) {
        require(implementation != address(0), "invalid implementation address");
        address deployedVault = Clones.cloneDeterministic(implementation, salt);
        if (data.length > 0) {
            Address.functionCall(deployedVault, data);
        }
        emit VaultProxyDeployed(implementation, deployedVault);
        return deployedVault;
    }

}
