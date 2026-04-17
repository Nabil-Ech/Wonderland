// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "targets/encoded_spell/src/Challenge.sol";
import "src/encoded_spell/Attack.sol";

contract EncodedSpellAttackTest is Test {
    Challenge challenge;
    EncodedSpellAttack attacker;

    function setUp() public {
        challenge = new Challenge(address(0));
        attacker  = new EncodedSpellAttack(address(challenge));
    }

    function test_attack() public {
        attacker.attack();
        assertTrue(challenge.isSolved(), "not solved");
    }
}
