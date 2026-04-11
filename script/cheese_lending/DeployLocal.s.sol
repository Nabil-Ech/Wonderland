// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {CheeseLending} from "targets/cheese_lending/src/CheeseLending.sol";
import {Cheese} from "targets/cheese_lending/src/Cheese.sol";

// Was: tried to reuse targets/cheese_lending/script/Deploy.s.sol, but it imports
// forge-ctf's CTFDeployer which has a different run() signature and wants a
// system/player pair from env. Fix: replicate the setup inline for local anvil.
contract DeployLocal is Script {
    function run() external {
        address player = vm.envAddress("PLAYER");

        vm.startBroadcast();

        Cheese gruy = new Cheese(0, "Gruyere", "GRY");
        Cheese emm  = new Cheese(0, "Emmental", "ETL");

        CheeseLending pool = new CheeseLending(player, address(gruy), address(emm));

        // Seed cow inline (avoids importing Cow.s.sol which uses broken "src/..." imports)
        address cow = msg.sender; // broadcaster acts as cow for local setup
        gruy.mint(player, 100 ether);
        emm.mint(player, 100 ether);
        gruy.mint(cow, 10 ether);
        emm.mint(cow, 10 ether);
        gruy.dropMint();
        emm.dropMint();

        gruy.approve(address(pool), type(uint256).max);
        emm.approve(address(pool), type(uint256).max);
        pool.supply(address(emm), 10 ether);
        pool.supply(address(gruy), 10 ether);

        vm.stopBroadcast();

        console.log("CheeseLending:", address(pool));
        console.log("Gruyere:", address(gruy));
        console.log("Emmental:", address(emm));
    }
}
