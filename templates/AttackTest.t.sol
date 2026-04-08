// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// Step 1: Paste the challenge interface or contract here
// interface IChallenge {
//     function isSolved() external view returns (bool);
//     function withdraw() external;
// }

// Step 2: Paste your attack contract here (or import it)
// import "../src/Challenge1Attack.sol";

/**
 * HOW TO RUN:
 *
 *   Without fork (blank chain, you set up everything):
 *     forge test -vvvv --match-test test_exploit
 *
 *   With fork (copies the REAL CTF chain state locally):
 *     forge test -vvvv --fork-url $CTF_RPC_URL --match-test test_exploit
 *
 *   The fork version lets you test your attack against the actual
 *   deployed challenge contract before you spend gas on-chain.
 */
contract AttackTest is Test {
    function test_exploit() public {
        // YOUR PRIVATE KEY's ADDRESS — the CTF gives you this
        address attacker = vm.envAddress("PLAYER_ADDRESS");

        // The address where the challenge contract is deployed
        // (the CTF tells you this)
        // address target = 0x1234...;

        // Impersonate your attacker account
        vm.startPrank(attacker);

        // ---- YOUR EXPLOIT HERE ----
        // Example: directly call a function
        // IChallenge(target).withdraw();
        //
        // Example: deploy an attack contract
        // Challenge1Attack attack = new Challenge1Attack(target);
        // attack.exploit();
        // ---------------------------

        vm.stopPrank();

        // Check if you won
        // assertTrue(IChallenge(target).isSolved(), "Challenge not solved!");
    }
}
