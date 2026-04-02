// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/**
 * Template attack script for CTF challenges.
 * Copy this for each challenge and modify.
 *
 * Usage:
 *   forge script script/Attack.s.sol --rpc-url $CTF_RPC_URL --broadcast --private-key $PRIVATE_KEY
 *
 * With gas optimization (smaller bytecode, cheaper deploy):
 *   FOUNDRY_PROFILE=ctf forge script script/Attack.s.sol --rpc-url $CTF_RPC_URL --broadcast --private-key $PRIVATE_KEY
 */
contract AttackScript is Script {
    function run() external {
        vm.startBroadcast();

        // 1. Get reference to the challenge contract
        // IChallenge target = IChallenge(TARGET_ADDRESS);

        // 2. Deploy attack contract if needed
        // Attack attack = new Attack(address(target));

        // 3. Execute exploit
        // attack.exploit();

        vm.stopBroadcast();
    }
}
