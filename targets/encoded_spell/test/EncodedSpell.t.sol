// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../src/Challenge.sol";

// Helper: receives a Spell calldata and returns its keccak256(abi.encode(spell))
contract AbiEncodeHelper {
    function encodeCalldata(Spell calldata spell) external pure returns (bytes32) {
        return keccak256(abi.encode(spell));
    }
    function encodeRaw(Spell calldata spell) external pure returns (bytes memory) {
        return abi.encode(spell);
    }
}

contract EncodedSpellTest is Test {
    Challenge challenge;
    AbiEncodeHelper helper;

    function setUp() public {
        challenge = new Challenge(address(0));
        helper = new AbiEncodeHelper();
    }

    // Verify: does abi.encode(calldata spell) == abi.encode(memory spell)?
    function test_abiEncodeBug() public {
        bytes32[8] memory encs;
        for (uint i; i < 8; i++) encs[i] = bytes32(uint256(1));
        Spell memory memSpell = Spell({ name: "CURAGA", enchantments: encs });

        bytes32 memHash  = keccak256(abi.encode(memSpell));
        bytes32 cdHash   = helper.encodeCalldata(memSpell);

        emit log_named_bytes32("memory hash  ", memHash);
        emit log_named_bytes32("calldata hash", cdHash);
        emit log_named_string("match?", memHash == cdHash ? "YES" : "NO - BUG CONFIRMED");

        // Show raw bytes to see exactly how they differ
        emit log_string("--- memory abi.encode ---");
        emit log_bytes(abi.encode(memSpell));
        emit log_string("--- calldata abi.encode ---");
        emit log_bytes(helper.encodeRaw(memSpell));
    }
}
