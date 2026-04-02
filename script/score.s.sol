// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";

// Simple interface to get the Oracle address from the Challenge
interface IChallenge {
    function ORACLE() external view returns (address);
}

contract FindRotation is Script {
    // Set your Challenge address here
    address constant CHALLENGE_ADDR = 0x022DE71b8f17182336c21Bc013E5C0E3B26edC09; 
    
    // The player address that will call poke() 
    // (If using an exploit contract, put its address here!)
    address constant PLAYER = 0x022DE71b8f17182336c21Bc013E5C0E3B26edC09; 

    function run() external {
        // 1. Get the Oracle address from the Challenge contract
        address oracleAddr = IChallenge(CHALLENGE_ADDR).ORACLE();
        
        // 2. Fetch current state directly from storage slots
        // Slot 0: _entropy, Slot 1: _scale, Slot 2: contributorCount
        uint256 currentEntropy = uint256(vm.load(oracleAddr, bytes32(uint256(0))));
        uint256 scale = uint256(vm.load(oracleAddr, bytes32(uint256(1))));
        uint256 count = uint256(vm.load(oracleAddr, bytes32(uint256(2))));
        uint256 balance = oracleAddr.balance;

        console.log("Current Oracle State fetched:");
        console.log("- Entropy:", currentEntropy);
        console.log("- Scale:  ", scale);
        console.log("- Count:  ", count);
        console.log("- Balance:", balance);

        if (count < 3) {
            console.log("WARNING: contributorCount is less than 3. Rotation will revert!");
        }

        // 3. Search for the Golden Block
        bool found = false;
        for (uint256 b = block.number; b < block.number + 1000; b++) {
            console.log("blocknymber", b);
            if (checkBlock(currentEntropy, scale, count, balance, b) == 0) {
                console.log("-----------------------------------------");
                console.log("GOLDEN BLOCK FOUND:", b);
                console.log("Current Block:     ", block.number);
                console.log("Wait for block:    ", b);
                console.log("-----------------------------------------");
                found = true;
                break;
            }
        }

        if (!found) console.log("No r=0 found in next 1000 blocks.");
    }

    function checkBlock(
        uint256 startEntropy, 
        uint256 scale, 
        uint256 count, 
        uint256 balance, 
        uint256 blockNum
    ) public pure returns (uint256) {
        // Simulate poke()
        uint256 pokedEntropy = startEntropy ^ uint256(keccak256(abi.encodePacked(blockNum, PLAYER)));

        // Simulate getRotation() assembly
        bytes32 key = keccak256(abi.encodePacked(pokedEntropy, count));
        uint256 keyInt = uint256(key);

        uint256 hi = keyInt >> 128;
        uint256 lo = keyInt & 0xffffffffffffffffffffffffffffffff;
        
        uint256 mixed = hi ^ (lo << 64);
        mixed = (mixed >> 7) | (mixed << 249);

        // Reconstruct the balance xor trick
        // Re-check: (balance / scale * scale) XOR (balance % scale)
        uint256 reconstructed = ((balance / scale) * scale) ^ (balance % scale);

        uint256 base = mixed ^ reconstructed;
        return base % 0x80;
    }
}