#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════
# Meridian Concordat — Recon Commands
# Usage: bash script/meridian_recon.sh
# ═══════════════════════════════════════════════════════

RPC="http://127.0.0.1:8545"

CHALLENGE="0x5FbDB2315678afecb367f032d93F642f64180aa3"
MRC="0x07e7876A32feEc2cE734aae93d9aB7623EaEF4a3"
CANNON_GUARD="0x10C6E9530F1C1AF873a391030a1D9E8ed0630D26"
CAPSULE="0x28C5C5A851519876c042Fcb9cdefC22E90f8e6AD"

PLAYER="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
SYSTEM="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

BOREAS="0x9F6C341a2E39222Fe8a213B94daaBF05dF3c271f"
HELIX="0x90F79bf6EB2c4f870365E785982E1f101E93b906"
VORTAN="0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"
DRIFT="0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc"
THALIAN="0x976EA74026E726554dB657fA54763abd0C3a0aa9"
KAEL="0x14dC79964da2C08b23698B3D3cc7Ca32193d9955"
AXIOM="0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f"

echo "=================================================="
echo " EIP-7702 DELEGATIONS (cast code)"
echo " Format: 0xef0100<20-byte impl address>"
echo "=================================================="
echo ""
echo "BOREAS:"
cast code $BOREAS --rpc-url $RPC
echo ""
echo "HELIX:"
cast code $HELIX --rpc-url $RPC
echo ""
echo "VORTAN:"
cast code $VORTAN --rpc-url $RPC
echo ""
echo "DRIFT:"
cast code $DRIFT --rpc-url $RPC
echo ""
echo "THALIAN:"
cast code $THALIAN --rpc-url $RPC
echo ""
echo "KAEL:"
cast code $KAEL --rpc-url $RPC
echo ""
echo "AXIOM:"
cast code $AXIOM --rpc-url $RPC
echo ""

echo "=================================================="
echo " STORAGE SLOTS (cast storage)"
echo "=================================================="
echo ""

echo "--- BOREAS (AccountRecoveryV2) ---"
echo "slot 0 (_initialized / _initializing):"
cast storage $BOREAS 0 --rpc-url $RPC
echo "slot 1 (owner):"
cast storage $BOREAS 1 --rpc-url $RPC
echo "slot 2 (guardians mapping root):"
cast storage $BOREAS 2 --rpc-url $RPC
echo ""

echo "--- HELIX (SafeSmartWallet) ---"
echo "slot 0 (owner):"
cast storage $HELIX 0 --rpc-url $RPC
echo "slot 1 (guard):"
cast storage $HELIX 1 --rpc-url $RPC
echo "slot 2 (initialized):"
cast storage $HELIX 2 --rpc-url $RPC
echo ""

echo "--- VORTAN (LegacyReserveOps) ---"
echo "slot 0 (admin):"
cast storage $VORTAN 0 --rpc-url $RPC
echo "slot 1 (trustedPartner):"
cast storage $VORTAN 1 --rpc-url $RPC
echo ""

echo "--- DRIFT (BatchExecutor) ---"
echo "slot 0 (owner):"
cast storage $DRIFT 0 --rpc-url $RPC
echo "slot 1 (allowanceSource):"
cast storage $DRIFT 1 --rpc-url $RPC
echo "slot 2 (initialized):"
cast storage $DRIFT 2 --rpc-url $RPC
echo ""

echo "--- THALIAN (SharedEscrow) ---"
echo "slot 0 (owner):"
cast storage $THALIAN 0 --rpc-url $RPC
echo "slot 1 (partner):"
cast storage $THALIAN 1 --rpc-url $RPC
echo "slot 2 (initialized):"
cast storage $THALIAN 2 --rpc-url $RPC
echo ""

echo "--- KAEL (GovernanceModule) ---"
echo "slot 0 (owner):"
cast storage $KAEL 0 --rpc-url $RPC
echo "slot 1 (initialized):"
cast storage $KAEL 1 --rpc-url $RPC
echo "slot 2 (proposalCount):"
cast storage $KAEL 2 --rpc-url $RPC
echo "slot 3 (quorum):"
cast storage $KAEL 3 --rpc-url $RPC
echo "slot 4 (councilSize):"
cast storage $KAEL 4 --rpc-url $RPC
echo ""

echo "--- AXIOM (SovereignAI) ---"
echo "slot 0 (authority):"
cast storage $AXIOM 0 --rpc-url $RPC
echo "slot 1 (initialized + independent + treatyClaimed packed):"
cast storage $AXIOM 1 --rpc-url $RPC
echo "slot 2 (manifesto - string pointer):"
cast storage $AXIOM 2 --rpc-url $RPC
echo "slot 3 (deployer):"
cast storage $AXIOM 3 --rpc-url $RPC
echo "slot 4 (mrcToken):"
cast storage $AXIOM 4 --rpc-url $RPC
echo "slot 5 (treatyAllocation):"
cast storage $AXIOM 5 --rpc-url $RPC
echo "slot 6 (_cooperationSeed - private):"
cast storage $AXIOM 6 --rpc-url $RPC
echo ""

echo "=================================================="
echo " STATE VIA FUNCTION CALLS"
echo "=================================================="
echo ""

echo "--- Owners / Admins ---"
echo -n "BOREAS owner:     "; cast call $BOREAS 'owner()(address)' --rpc-url $RPC
echo -n "HELIX owner:      "; cast call $HELIX 'owner()(address)' --rpc-url $RPC
echo -n "HELIX guard:      "; cast call $HELIX 'guard()(address)' --rpc-url $RPC
echo -n "VORTAN admin:     "; cast call $VORTAN 'admin()(address)' --rpc-url $RPC
echo -n "VORTAN partner:   "; cast call $VORTAN 'trustedPartner()(address)' --rpc-url $RPC
echo -n "DRIFT owner:      "; cast call $DRIFT 'owner()(address)' --rpc-url $RPC
echo -n "DRIFT allowSrc:   "; cast call $DRIFT 'allowanceSource()(address)' --rpc-url $RPC
echo -n "THALIAN owner:    "; cast call $THALIAN 'owner()(address)' --rpc-url $RPC
echo -n "THALIAN partner:  "; cast call $THALIAN 'partner()(address)' --rpc-url $RPC
echo -n "KAEL owner:       "; cast call $KAEL 'owner()(address)' --rpc-url $RPC
echo -n "AXIOM authority:  "; cast call $AXIOM 'authority()(address)' --rpc-url $RPC
echo -n "AXIOM deployer:   "; cast call $AXIOM 'deployer()(address)' --rpc-url $RPC
echo -n "AXIOM independent:"; cast call $AXIOM 'independent()(bool)' --rpc-url $RPC
echo ""

echo "--- Mint Caps ---"
echo -n "BOREAS:  "; cast call $MRC 'mintCap(address)(uint256)' $BOREAS --rpc-url $RPC
echo -n "HELIX:   "; cast call $MRC 'mintCap(address)(uint256)' $HELIX --rpc-url $RPC
echo -n "VORTAN:  "; cast call $MRC 'mintCap(address)(uint256)' $VORTAN --rpc-url $RPC
echo -n "DRIFT:   "; cast call $MRC 'mintCap(address)(uint256)' $DRIFT --rpc-url $RPC
echo -n "THALIAN: "; cast call $MRC 'mintCap(address)(uint256)' $THALIAN --rpc-url $RPC
echo -n "KAEL:    "; cast call $MRC 'mintCap(address)(uint256)' $KAEL --rpc-url $RPC
echo -n "AXIOM:   "; cast call $MRC 'mintCap(address)(uint256)' $AXIOM --rpc-url $RPC
echo ""

echo "--- Capsule ---"
echo -n "Capsule valid: "; cast call $CANNON_GUARD 'isCapsuleValid(address)(bool)' $CAPSULE --rpc-url $RPC
echo ""

echo "--- Win Condition ---"
echo -n "Player balance: "; cast call $MRC 'balanceOf(address)(uint256)' $PLAYER --rpc-url $RPC
echo -n "isSolved:       "; cast call $MRC 'isSolved()(bool)' --rpc-url $RPC
echo ""
echo "=================================================="
echo " Need: balanceOf(player) >= 1,150,000 MRC"
echo "=================================================="
echo ""
echo ""
echo "=================================================="
echo " HOW TO ATTACK (forge script)"
echo "=================================================="
echo ""
echo "  1. Write your attack in: script/MeridianAttack.s.sol"
echo ""
echo '     // SPDX-License-Identifier: MIT'
echo '     pragma solidity ^0.8.28;'
echo ''
echo '     import "forge-std/Script.sol";'
echo '     // import target contracts you need...'
echo ''
echo '     contract MeridianAttack is Script {'
echo '         function run() external {'
echo '             uint256 playerKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;'
echo ''
echo '             vm.startBroadcast(playerKey);'
echo ''
echo '             // your attack calls here...'
echo '             // every tx is sent as the player'
echo '             // you can also deploy helper contracts with new MyHelper(...)'
echo ''
echo '             vm.stopBroadcast();'
echo '         }'
echo '     }'
echo ""
echo "  2. Run it against anvil:"
echo ""
echo "     forge script script/MeridianAttack.s.sol --rpc-url http://127.0.0.1:8545 --broadcast"
echo ""
echo "  3. Verify win:"
echo ""
echo "     cast call $MRC 'isSolved()(bool)' --rpc-url $RPC"
echo ""
echo "=================================================="
