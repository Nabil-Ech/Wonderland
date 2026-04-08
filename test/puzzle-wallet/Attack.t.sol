// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "src/puzzle-wallet/PuzzleWalletAttack.sol";

contract PuzzleWalletTest is Test {
    function test_exploit() public {
        address attacker = vm.envAddress("PLAYER_ADDRESS");
        address target = 0x3D9BAbAABEBceCF0D3603CA02926d5CECCD3CDE7;

        // Give the attacker enough ETH for the exploit
        vm.deal(attacker, 1 ether);
        vm.startPrank(attacker);

        // Deploy and run the attack
        PuzzleWalletAttack attack = new PuzzleWalletAttack(target);
        attack.exploit{value: 0.001 ether}();

        vm.stopPrank();

        // Verify: we should now be the admin (slot 1 of the proxy)
        address admin = IPuzzleProxy(target).admin();
        assertEq(admin, attacker, "Not admin yet!");
    }
}
