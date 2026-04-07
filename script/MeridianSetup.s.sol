// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {Challenge} from "targets/meridian-concordat/src/Challenge.sol";

/// @title Deploy Challenge only — delegations handled by meridian_setup.sh
contract MeridianSetup is Script {
    // Anvil default keys
    uint256 constant SYSTEM_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external {
        address system  = vm.addr(SYSTEM_KEY);
        address player  = vm.addr(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d);
        address boreas  = vm.addr(0x5de4111afe1508cf82f0b5e28cd0ca7e1a02b8e50a2b27a548e6d371b44b8b14);
        address helix   = vm.addr(0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6);
        address vortan  = vm.addr(0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a);
        address drift   = vm.addr(0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba);
        address thalian = vm.addr(0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e);
        address kael    = vm.addr(0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356);
        address axiom   = vm.addr(0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97);

        address[] memory reserves = new address[](7);
        reserves[0] = boreas;
        reserves[1] = helix;
        reserves[2] = vortan;
        reserves[3] = drift;
        reserves[4] = thalian;
        reserves[5] = kael;
        reserves[6] = axiom;

        vm.broadcast(SYSTEM_KEY);
        Challenge challenge = new Challenge(system, player, reserves);

        console.log("CHALLENGE=%s", address(challenge));
    }
}
