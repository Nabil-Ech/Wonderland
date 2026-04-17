// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;
import "forge-std/Test.sol";
import "../src/Challenge.sol";

contract ManaTest is Test {
    Challenge challenge;
    function setUp() public {
        challenge = new Challenge(address(0));
    }

    // Test: runes.length = 200 (no padding), total = 4+32+32+32+200 = 300 bytes
    function test_runes_200_no_padding() public {
        bytes memory rawCall = abi.encodePacked(
            challenge.createMagicCircle.selector,
            uint256(0x40),    // offset to runes
            bytes32(0),       // masterSeal
            uint256(200),     // runes.length = 200 (claims 200, provides 200, no extra padding)
            new bytes(200)    // 200 bytes of data
        );
        assertEq(rawCall.length, 300, "must be 300");
        (bool ok,) = address(challenge).call(rawCall);
        emit log_named_string("200-no-pad ok?", ok ? "YES" : "NO");
    }

    // Test: runes.length = 192, total = 4+32+32+32+192 = 292 + 8 trailing = 300
    function test_runes_192_plus_trailing() public {
        bytes memory rawCall = abi.encodePacked(
            challenge.createMagicCircle.selector,
            uint256(0x40),
            bytes32(0),
            uint256(192),     // runes.length = 192 (multiple of 32)
            new bytes(192),   // 192 bytes data
            new bytes(8)      // 8 trailing bytes to hit 300
        );
        assertEq(rawCall.length, 300, "must be 300");
        (bool ok,) = address(challenge).call(rawCall);
        emit log_named_string("192+trail ok?", ok ? "YES" : "NO");
        if (ok) emit log_named_uint("mana", challenge.mana());
    }

    // Test: standard call with 256-byte runes
    function test_runes_256_standard() public {
        bytes memory rawCall = abi.encodePacked(
            challenge.createMagicCircle.selector,
            uint256(0x40),
            bytes32(0),
            uint256(256),
            new bytes(256)
        );
        assertEq(rawCall.length, 356, "must be 356");
        (bool ok,) = address(challenge).call(rawCall);
        emit log_named_string("256 std ok?", ok ? "YES" : "NO");
        if (ok) emit log_named_uint("mana", challenge.mana());
    }
}
