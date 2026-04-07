// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-ctf/CTFDeployer.sol";
import "src/UECallNft.sol";
import "src/Challenge.sol";

contract Deploy is CTFDeployer {
    function deploy(address system, address player) internal override returns (address challenge) {
        vm.startBroadcast(system);

        UECallNft nftContract = new UECallNft();

        nftContract.mintUEC{value: 0.01 ether}();
        nftContract.mintUEC{value: 0.01 ether}();
        nftContract.mintUEC{value: 0.01 ether}();
        nftContract.mintUEC{value: 0.01 ether}();
        nftContract.mintUEC{value: 0.01 ether}();

        nftContract.transferFrom(system, address(0x2222222), 1);
        nftContract.transferFrom(system, address(0x3333333), 2);
        nftContract.transferFrom(system, address(0x4444444), 3);
        nftContract.transferFrom(system, address(0x5555555), 4);
        nftContract.transferFrom(system, address(0x6666666), 5);

        challenge = address(new Challenge(player, nftContract));

        vm.stopBroadcast();
    }
}
