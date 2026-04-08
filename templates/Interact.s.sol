// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/**
 * Quick interaction script - for calling functions on deployed contracts
 * without needing a full attack contract.
 *
 * Usage:
 *   forge script script/Interact.s.sol --rpc-url $CTF_RPC_URL --broadcast --private-key $PRIVATE_KEY
 */
contract InteractScript is Script {
    function run() external {
        vm.startBroadcast();

        // Direct low-level call example:
        // address target = 0x...;
        // (bool success,) = target.call(abi.encodeWithSignature("functionName(uint256)", 42));
        // require(success, "call failed");

        // Or with value:
        // (bool success,) = target.call{value: 1 ether}(abi.encodeWithSignature("deposit()"));

        vm.stopBroadcast();
    }
}
