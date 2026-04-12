// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import {Challenge} from "src/Challenge.sol";

contract DeployLocal is Script {
    function run() external {
        address player = vm.envAddress("PLAYER");

        vm.startBroadcast();

        // Challenge constructor: Oracle gets 1.337 ETH, Score gets 10 ETH
        Challenge challenge = new Challenge{value: 11.337 ether}(player);

        vm.stopBroadcast();

        address oracle = address(challenge.ORACLE());
        address score  = address(challenge.SCORE());

        // Read raw oracle state from storage for the JS script
        uint256 entropy = uint256(vm.load(oracle, bytes32(uint256(0))));
        uint256 balance = oracle.balance;
        bytes32 seed    = vm.load(score, bytes32(uint256(0)));

        console.log("=== SCORE CHALLENGE DEPLOYED ===");
        console.log("CHALLENGE :", address(challenge));
        console.log("ORACLE    :", oracle);
        console.log("SCORE     :", score);
        console.log("PLAYER    :", player);
        console.log("---");
        console.log("Oracle entropy (slot 0):", entropy);
        console.log("Oracle balance (wei)   :", balance);
        console.log("Score seed             :");
        console.logBytes32(seed);
        console.log("Block number           :", block.number);
    }
}
