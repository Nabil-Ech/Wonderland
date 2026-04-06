// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";

// Was: can't import Challenge.sol (its internal imports don't resolve from our root)
// Fix: deploy using the pre-compiled bytecode from bin/ — same approach the CTF uses
contract DeployChallenge is Script {
    function run() external {
        vm.startBroadcast();

        // Read pre-compiled Overseer bytecode (the CTF may use a custom-compiled Overseer)
        // For now, we deploy Challenge from source by encoding constructor args manually

        // Challenge constructor: constructor(address player) payable
        // player = msg.sender (our broadcaster EOA)
        address player = msg.sender;

        // We need to deploy Challenge, but can't import it.
        // Workaround: use forge create from CLI instead.
        // This script just logs what we need.
        console.log("Player:", player);

        vm.stopBroadcast();
    }
}
