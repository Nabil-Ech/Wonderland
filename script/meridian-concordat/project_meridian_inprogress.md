---
name: Meridian Concordat in progress
description: Meridian Concordat challenge — EIP-7702 multi-station MRC token exploit, local anvil setup working, attack not yet written
type: project
---

Meridian Concordat challenge is in progress as of 2026-04-07.

**Setup:**
- Local anvil replication works via `bash script/meridian-concordat/setup.sh` (Prague hardfork, EIP-7702 delegations via anvil_setCode)
- Recon script: `bash script/meridian-concordat/recon.sh` dumps delegations, storage, mint caps
- Test harness: `test/meridian-concordat/Attack.t.sol` uses vm.signDelegation to simulate 7702
- Attack is empty — user wants to find vulnerabilities themselves

**Win condition:** `MRC.balanceOf(player) >= 1,150,000` (1.15M MRC tokens)

**Stations and mint caps:**
- BOREAS (500k) → AccountRecoveryV2
- HELIX (500k) → SafeSmartWallet
- VORTAN (200k) → LegacyReserveOps
- DRIFT (0) → BatchExecutor
- THALIAN (200k) → SharedEscrow
- KAEL (300k) → GovernanceModule
- AXIOM (300k) → SovereignAI

**How to apply:** User is exploring this challenge solo. Don't reveal vulnerabilities unless asked. Help with tooling/setup only.
