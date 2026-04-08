// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/ScoreAttack.sol";

contract ScoreTest is Test {
    address constant CHALLENGE_ADDR = 0x8F1B5Dd52F28FA9D2e20F375d4555aEe03871902;
    address constant PLAYER = 0x980Fd40933481De5151054fEEEE7fb33039B8e32;

    IChallenge challenge;
    IOracle oracle;
    IScore score;

    function setUp() public {
        challenge = IChallenge(CHALLENGE_ADDR);
        oracle = IOracle(challenge.ORACLE());
        score = IScore(challenge.SCORE());
    }

    /// @notice Search for contribute values that give rotation = 0
    function test_findRotation() public {
        vm.startPrank(PLAYER);

        // We need to find (v1, v2, v3) such that after 3 contribute() calls
        // from the attack contract address, getRotation() == 0.

        // First, compute the attack contract address (CREATE from PLAYER with current nonce)
        uint256 playerNonce = vm.getNonce(PLAYER);
        address attackAddr = vm.computeCreateAddress(PLAYER, playerNonce);
        console.log("Attack contract will be at:", attackAddr);

        // Read initial oracle state
        uint256 initialEntropy = uint256(vm.load(address(oracle), bytes32(uint256(0))));
        console.log("Initial entropy:");
        console.logBytes32(bytes32(initialEntropy));

        uint256 oracleBalance = address(oracle).balance;
        console.log("Oracle balance:", oracleBalance);

        // Search for values that give rotation = 0
        // Rotation depends on: _entropy (after contributes), contributorCount (=3),
        // _scale (=v1+v2+v3), and oracle balance
        bool found = false;
        uint256 bestV1;
        uint256 bestV2;
        uint256 bestV3;

        for (uint256 v1 = 1; v1 <= 200 && !found; v1++) {
            for (uint256 v2 = 1; v2 <= 200 && !found; v2++) {
                for (uint256 v3 = 1; v3 <= 200 && !found; v3++) {
                    // Simulate entropy updates
                    uint256 e = initialEntropy;
                    e = uint256(keccak256(abi.encodePacked(e, v1, attackAddr)));
                    e = uint256(keccak256(abi.encodePacked(e, v2, attackAddr)));
                    e = uint256(keccak256(abi.encodePacked(e, v3, attackAddr)));

                    uint256 scale = v1 + v2 + v3;
                    uint256 count = 3;

                    // Compute rotation (replicate getRotation assembly)
                    uint256 rotation = _computeRotation(e, count, scale, oracleBalance);

                    if (rotation == 0) {
                        found = true;
                        bestV1 = v1;
                        bestV2 = v2;
                        bestV3 = v3;
                        console.log("FOUND! v1=%d v2=%d v3=%d", v1, v2, v3);
                    }
                }
            }
        }

        require(found, "No rotation=0 found in search space");
        vm.stopPrank();
    }

    /// @notice Full exploit test
    function test_exploit() public {
        vm.startPrank(PLAYER);

        // First find contribute values (inline search)
        uint256 playerNonce = vm.getNonce(PLAYER);
        address attackAddr = vm.computeCreateAddress(PLAYER, playerNonce);
        uint256 initialEntropy = uint256(vm.load(address(oracle), bytes32(uint256(0))));
        uint256 oracleBalance = address(oracle).balance;

        uint256 v1;
        uint256 v2;
        uint256 v3;
        bool found;

        for (v1 = 1; v1 <= 200 && !found; v1++) {
            for (v2 = 1; v2 <= 200 && !found; v2++) {
                for (v3 = 1; v3 <= 200 && !found; v3++) {
                    uint256 e = initialEntropy;
                    e = uint256(keccak256(abi.encodePacked(e, v1, attackAddr)));
                    e = uint256(keccak256(abi.encodePacked(e, v2, attackAddr)));
                    e = uint256(keccak256(abi.encodePacked(e, v3, attackAddr)));
                    uint256 scale = v1 + v2 + v3;
                    if (_computeRotation(e, 3, scale, oracleBalance) == 0) {
                        found = true;
                        // Undo the last increments from the for loop
                        break;
                    }
                }
                if (found) break;
            }
            if (found) break;
        }

        require(found, "No rotation=0 found");
        console.log("Using v1=%d v2=%d v3=%d", v1, v2, v3);

        // Deploy attack contract
        ScoreAttack attacker = new ScoreAttack(CHALLENGE_ADDR);
        console.log("Attack contract at:", address(attacker));
        assertEq(address(attacker), attackAddr, "Address mismatch");

        // Run exploit with high gas limit
        attacker.exploit{gas: 50_000_000}(v1, v2, v3);

        // Verify
        assertTrue(challenge.isSolved(), "Challenge not solved!");
        console.log("SOLVED!");

        vm.stopPrank();
    }

    /// @notice Replicate Oracle.getRotation() assembly logic
    function _computeRotation(
        uint256 _entropy,
        uint256 _count,
        uint256 _scale,
        uint256 _balance
    ) internal pure returns (uint256) {
        uint256 key = uint256(keccak256(abi.encodePacked(_entropy, _count)));

        uint256 hi = key >> 128;
        uint256 lo = key & type(uint128).max;
        uint256 mixed = hi ^ (lo << 64);
        mixed = (mixed >> 7) | (mixed << 249);

        uint256 reconstructed = ((_balance / _scale) * _scale) ^ (_balance % _scale);

        uint256 base = mixed ^ reconstructed;
        return base % 128;
    }
}
