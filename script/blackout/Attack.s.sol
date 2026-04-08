// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "../src/blacoutAttack.sol";
import "../targets/blackout/src/Challenge.sol";
import "../targets/blackout/src/SentinelGate.sol";

contract SentinelAttackScript is Script {
    function run() external {
        vm.startBroadcast();
        // Was: address(this) is ephemeral in scripts, use msg.sender (the broadcaster)
        Challenge challenge = new Challenge{value: 1 ether}(msg.sender);
        // Was: GATE() returns SentinelGate contract type, needs cast to address then ISentinelGate
        ISentinelGate target = ISentinelGate(address(challenge.GATE()));
        blackoutAttack attack = new blackoutAttack(target, msg.sender);
        // Was: attack() never called
        attack.attack();

        bool success = challenge.isSolved();
        console.log("issolved", success);

        vm.stopBroadcast();
    }
}