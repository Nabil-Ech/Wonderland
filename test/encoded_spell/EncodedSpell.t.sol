// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "targets/encoded_spell/src/Challenge.sol";

contract EncodedSpellTest is Test {
    Challenge challenge;

    function setUp() public {
        challenge = new Challenge(address(0));
    }

    // Test: can we send 300-byte calldata where runes.length=256 but only 200 data bytes are present?
    function test_truncatedCalldata() public {
        // Build a Spell we'll pass to cast()
        bytes32[8] memory encs;
        for (uint i; i < 8; i++) encs[i] = bytes32(uint256(1)); // all 1s — must beat weakSeals (zeros)

        Spell memory spell = Spell({ name: "CURAGA", enchantments: encs });
        bytes32 masterSeal = keccak256(abi.encode(spell));

        // Craft exactly 300 bytes of calldata:
        //   4   bytes: selector
        //  32   bytes: offset to runes = 0x40
        //  32   bytes: newMasterSeal
        //  32   bytes: runes.length = 256
        // 200   bytes: runes data (zeros) — claims 256 but only 200 provided
        // Total = 300
        bytes memory rawCall = abi.encodePacked(
            challenge.createMagicCircle.selector,
            uint256(0x40),      // offset to runes tail (64, relative to param start)
            masterSeal,          // newMasterSeal
            uint256(256),       // runes.length claims 256 bytes
            new bytes(200)      // only 200 zero bytes (truncated)
        );
        assertEq(rawCall.length, 300, "calldata must be exactly 300 bytes");

        emit log_string("=== calling createMagicCircle with 300-byte calldata ===");
        (bool ok, bytes memory ret) = address(challenge).call(rawCall);
        if (!ok) {
            emit log_string("REVERTED");
            emit log_bytes(ret);
            return;
        }

        emit log_named_uint("mana", challenge.mana());        // expect 300
        emit log_named_bytes32("masterSeal", challenge.masterSeal());

        // All weakSeals should be 0 (runes data was all zeros)
        for (uint i; i < 8; i++) {
            emit log_named_uint(string(abi.encodePacked("weakSeal[", i, "]")), uint256(challenge.weakSeals(i)));
        }

        // Now cast the spell
        challenge.cast(spell);
        assertTrue(challenge.isSolved(), "not solved");
        emit log_string("SOLVED!");
    }
}
