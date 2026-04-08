// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
// Was: missing IMeridianCredits import for the cast
import {IChallenge, IMeridianCredits} from "src/meridian-concordat/IMeridianConcordat.sol";
//import {MeridianConcordatAttack} from "src/meridian-concordat/MeridianConcordatAttack.sol";
import {MCAttack} from "src/meridian-concordat/MCAttack.sol";

contract MeridianConcordatScript is Script {
    function run() external {
        // Was: CHALLENGE_ADDRESS/PLAYER_ADDRESS didn't match .env which uses CHALLENGE/PLAYER
        address challengeAddr = vm.envAddress("CHALLENGE");
        address player = vm.envAddress("PLAYER");
        IChallenge challenge = IChallenge(challengeAddr);

        // Was: hardcoded wrong capsule address — read from .env instead
        address capsule = vm.envAddress("CAPSULE");

        vm.startBroadcast();

        // Was: MeridianConcordatAttack — wrong name, contract is MCAttack
        MCAttack attack = new MCAttack(
            challenge.BOREAS(),
            challenge.HELIX(),
            challenge.AXIOM(),
            // Was: address not auto-convertible to IMeridianCredits
            IMeridianCredits(challenge.MRC()),
            capsule,
            player
        );
        // Was: exploit() doesn't exist, function is named attack()
        attack.attack();

        vm.stopBroadcast();
    }
}
