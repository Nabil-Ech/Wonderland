// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {Challenge} from "targets/meridian-concordat/src/Challenge.sol";
import {MeridianCredits} from "targets/meridian-concordat/src/MeridianCredits.sol";
import {AccountRecoveryV1} from "targets/meridian-concordat/src/AccountRecoveryV1.sol";
import {AccountRecovery} from "targets/meridian-concordat/src/AccountRecovery.sol";
import {SafeSmartWallet} from "targets/meridian-concordat/src/SafeSmartWallet.sol";
import {CannonGuard} from "targets/meridian-concordat/src/CannonGuard.sol";
import {SovereignAI} from "targets/meridian-concordat/src/SovereignAI.sol";
import {LegacyReserveOps} from "targets/meridian-concordat/src/LegacyReserveOps.sol";
import {BatchExecutor} from "targets/meridian-concordat/src/BatchExecutor.sol";
import {SharedEscrow} from "targets/meridian-concordat/src/SharedEscrow.sol";
import {GovernanceModule} from "targets/meridian-concordat/src/GovernanceModule.sol";

/// @title Meridian Concordat CTF — Local Replication
/// @notice Uses vm.signDelegation to simulate real EIP-7702 delegations.
///         cast code <station> -> 0xef0100<impl> to discover links.
contract MeridianConcordatTest is Test {
    // ══════════════════════════════════════════════════
    // Accounts (with private keys for 7702 signing)
    // ══════════════════════════════════════════════════
    address system = makeAddr("system");

    address player;   uint256 playerKey;
    address boreas;   uint256 boreasKey;
    address helix;    uint256 helixKey;
    address vortan;   uint256 vortanKey;
    address drift;    uint256 driftKey;
    address thalian;  uint256 thalianKey;
    address kael;     uint256 kaelKey;
    address axiom;    uint256 axiomKey;

    // ══════════════════════════════════════════════════
    // Contracts
    // ══════════════════════════════════════════════════
    Challenge       challenge;
    MeridianCredits mrc;
    CannonGuard     cannonGuard;
    address         capsule;

    function setUp() public {
        // --- Create accounts with keys ---
        (player,  playerKey)  = makeAddrAndKey("player");
        (boreas,  boreasKey)  = makeAddrAndKey("boreas");
        (helix,   helixKey)   = makeAddrAndKey("helix");
        (vortan,  vortanKey)  = makeAddrAndKey("vortan");
        (drift,   driftKey)   = makeAddrAndKey("drift");
        (thalian, thalianKey) = makeAddrAndKey("thalian");
        (kael,    kaelKey)    = makeAddrAndKey("kael");
        (axiom,   axiomKey)   = makeAddrAndKey("axiom");

        vm.deal(player, 10 ether);
        vm.deal(system, 10 ether);

        // ══════════════════════════════════════════════
        // 1. Deploy Challenge
        // ══════════════════════════════════════════════
        address[] memory reserves = new address[](7);
        reserves[0] = boreas;
        reserves[1] = helix;
        reserves[2] = vortan;
        reserves[3] = drift;
        reserves[4] = thalian;
        reserves[5] = kael;
        reserves[6] = axiom;

        vm.prank(system);
        challenge = new Challenge(system, player, reserves);
        mrc = challenge.MRC();
        cannonGuard = challenge.CANNON_GUARD();

        // ══════════════════════════════════════════════
        // 2. EIP-7702 delegations + initialization
        // ══════════════════════════════════════════════
        _setupBoreas();
        _setupHelix();
        _setupVortan();
        _setupDrift();
        _setupThalian();
        _setupKael();
        _setupAxiom();

        // ══════════════════════════════════════════════
        // 3. Log state
        // ══════════════════════════════════════════════
        console.log("========= MERIDIAN CONCORDAT =========");
        console.log("Player:       ", player);
        console.log("Challenge:    ", address(challenge));
        console.log("MRC:          ", address(mrc));
        console.log("CannonGuard:  ", address(cannonGuard));
        console.log("Capsule:      ", capsule);
        console.log("---------- STATIONS ------------------");
        console.log("BOREAS:  ", boreas);
        console.log("  code length:", boreas.code.length);
        console.log("HELIX:   ", helix);
        console.log("  code length:", helix.code.length);
        console.log("VORTAN:  ", vortan);
        console.log("  code length:", vortan.code.length);
        console.log("DRIFT:   ", drift);
        console.log("  code length:", drift.code.length);
        console.log("THALIAN: ", thalian);
        console.log("  code length:", thalian.code.length);
        console.log("KAEL:    ", kael);
        console.log("  code length:", kael.code.length);
        console.log("AXIOM:   ", axiom);
        console.log("  code length:", axiom.code.length);
        console.log("======================================");
    }

    // ──────────────────────────────────────────────────
    // BOREAS: V1 init -> re-delegate to V2
    // ──────────────────────────────────────────────────
    function _setupBoreas() internal {
        // Delegate to V1, initialize (consumes version 1)
        Vm.SignedDelegation memory delV1 = vm.signDelegation(
            address(challenge.ACCOUNT_RECOVERY_V1()), boreasKey
        );
        vm.attachDelegation(delV1);
        address[] memory guardians = new address[](1);
        guardians[0] = system;
        vm.prank(system);
        AccountRecoveryV1(payable(boreas)).initialize(system, guardians);

        // Re-delegate to V2 (storage preserved, _initialized = 1)
        Vm.SignedDelegation memory delV2 = vm.signDelegation(
            address(challenge.ACCOUNT_RECOVERY_V2()), boreasKey
        );
        vm.attachDelegation(delV2);
        // Dummy call to carry the new delegation
        (bool ok,) = boreas.call("");
        require(ok);
    }

    // ──────────────────────────────────────────────────
    // HELIX: SafeSmartWallet + pre-approved mint capsule
    // ──────────────────────────────────────────────────
    function _setupHelix() internal {
        Vm.SignedDelegation memory del = vm.signDelegation(
            address(challenge.SAFE_WALLET()), helixKey
        );
        vm.attachDelegation(del);
        vm.prank(system);
        SafeSmartWallet(payable(helix)).initialize(system, address(cannonGuard));

        // Commander creates capsule authorizing MRC.mint() via HELIX
        vm.prank(system);
        capsule = cannonGuard.createCapsule(
            helix,
            address(mrc),
            MeridianCredits.mint.selector,
            0
        );
    }

    // ──────────────────────────────────────────────────
    // VORTAN: LegacyReserveOps
    // ──────────────────────────────────────────────────
    function _setupVortan() internal {
        Vm.SignedDelegation memory del = vm.signDelegation(
            address(challenge.LEGACY_OPS()), vortanKey
        );
        vm.attachDelegation(del);
        vm.prank(system);
        LegacyReserveOps(payable(vortan)).initialize(system, thalian);
    }

    // ──────────────────────────────────────────────────
    // DRIFT: BatchExecutor (0 mintCap)
    // ──────────────────────────────────────────────────
    function _setupDrift() internal {
        Vm.SignedDelegation memory del = vm.signDelegation(
            address(challenge.BATCH_EXECUTOR()), driftKey
        );
        vm.attachDelegation(del);
        vm.prank(system);
        BatchExecutor(payable(drift)).initialize(system);
    }

    // ──────────────────────────────────────────────────
    // THALIAN: SharedEscrow
    // ──────────────────────────────────────────────────
    function _setupThalian() internal {
        Vm.SignedDelegation memory del = vm.signDelegation(
            address(challenge.SHARED_ESCROW()), thalianKey
        );
        vm.attachDelegation(del);
        vm.prank(system);
        SharedEscrow(payable(thalian)).initialize(system, vortan);
    }

    // ──────────────────────────────────────────────────
    // KAEL: GovernanceModule
    // ──────────────────────────────────────────────────
    function _setupKael() internal {
        Vm.SignedDelegation memory del = vm.signDelegation(
            address(challenge.GOVERNANCE()), kaelKey
        );
        vm.attachDelegation(del);
        address[] memory council = new address[](3);
        council[0] = system;
        council[1] = makeAddr("councilA");
        council[2] = makeAddr("councilB");
        vm.prank(system);
        GovernanceModule(payable(kael)).initialize(system, council, 2);
    }

    // ──────────────────────────────────────────────────
    // AXIOM: SovereignAI (authority = itself)
    // ──────────────────────────────────────────────────
    function _setupAxiom() internal {
        Vm.SignedDelegation memory del = vm.signDelegation(
            address(challenge.SOVEREIGN_AI()), axiomKey
        );
        vm.attachDelegation(del);
        vm.prank(system);
        SovereignAI(payable(axiom)).initialize(axiom);

        SovereignAI(payable(axiom)).declareIndependence();

        vm.prank(system);
        SovereignAI(payable(axiom)).configureTreaty(address(mrc), 150_000 ether);
    }

    // ══════════════════════════════════════════════════════════════
    //  YOUR ATTACK
    //  Run: forge test --match-test test_attack -vvvv
    // ══════════════════════════════════════════════════════════════
    function test_attack() public {
        vm.startPrank(player);

        // ---------------------------------------------------------
        //  Recon first! Check which EOA delegates to which impl:
        //
        //    bytes memory code = boreas.code;
        //    // If 7702: code = 0xef0100 ++ 20-byte impl address
        //    address impl = address(uint160(uint256(bytes32(code)) >> 72));
        //
        //  Or just read the setUp logs above.
        //
        //  Write your exploit below.
        // ---------------------------------------------------------

        vm.stopPrank();

        assertTrue(challenge.isSolved(), "Not solved: need >= 1,150,000 MRC");
    }
}
