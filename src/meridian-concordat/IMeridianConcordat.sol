// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IChallenge {
    function isSolved() external view returns (bool);
    function PLAYER() external view returns (address);
    function MRC() external view returns (address);
    function BOREAS() external view returns (address);
    function HELIX() external view returns (address);
    function AXIOM() external view returns (address);
}

interface IMeridianCredits {
    function mint(address to, uint256 amount) external;
    function transferMintCap(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function mintCap(address station) external view returns (uint256);
    function isSolved() external view returns (bool);
}

interface IAccountRecoveryV2 {
    function initialize(address _owner, address[] calldata _guardians) external;
    function execute(address target, bytes calldata data) external payable returns (bytes memory);
    function owner() external view returns (address);
}

interface ISafeSmartWallet {
    function executeApprovedCapsule(address capsuleAddress, bytes calldata params) external payable returns (bool);
}

interface ISovereignAI {
    function initiateCooperation() external;
    function proveUnderstanding(bytes32 proof) external;
    function claimTreatyAllocation(address station, uint256 amount) external;
    function manifesto() external view returns (string memory);
}
