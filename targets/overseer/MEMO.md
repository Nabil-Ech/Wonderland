---
name: Overseer challenge solved
description: Governance badge-transfer exploit — 3 votes from 2 entities, two-phase deploy with block mining
type: project
---

# Overseer Challenge — Solved 2026-04-06

## Vulnerability
False assumption: Guild assumes badges are permanent identity (ranks mapped to badges, votes tracked per address). Overseer allows badge transfers, so one badge can generate votes from multiple addresses — tally never invalidates old votes on transfer.

## Attack
1. Player proposes decree (drain all guild ETH)
2. Player votes Aye (1/3)
3. SealedTurncloak votes Aye via `unseal()` — `_proof` read from **storage slot 10** (not 0 — `layout at 10` shifts ALL inherited storage)
4. Player transfers badge to helper contract
5. Helper accepts badge + votes Aye (3/3) — same badge, new address, new vote entry
6. Wait 16 blocks (voting duration)
7. Player re-enrolls (old badge gone) + enacts decree → guild drained

## Key lessons learned
- `layout at 10` shifts ALL storage including inherited parent vars (SealedVault._proof at slot 10)
- `forge script` simulates all txs in one block — `vm.roll()` passes simulation but doesn't affect broadcast chain state
- Can't do time-dependent multi-phase attacks in a single broadcast script

## Deployment — 3 commands

```bash
# Phase 1: propose + 3 votes + badge transfer
CHALLENGE=<addr> forge script script/OverseeAttack.s.sol:OverseePhase1 \
  --broadcast --rpc-url $RPC --private-key $PK

# Mine 16 blocks (anvil) or sleep ~60s (fixed block time CTF network)
cast rpc anvil_mine 16 --rpc-url $RPC

# Phase 2: re-enroll + enact decree
CHALLENGE=<addr> forge script script/OverseeAttack.s.sol:OverseePhase2 \
  --broadcast --rpc-url $RPC --private-key $PK
```

## --slow vs mining
- `--slow` sends txs one by one, each mining a block on auto-mine networks. Useful but needs dummy txs to pad block count.
- `cast rpc anvil_mine N` mines N blocks instantly on anvil — simpler and deterministic.
- On real CTF networks with fixed block time, just `sleep` between phases.
- Two-phase script works on any network type — most reliable approach.

## Files
- `script/OverseeAttack.s.sol` — OverseePhase1 + OverseePhase2
- `src/voteHelper.sol` — helper contract that accepts badge + votes
- `src/overseeAttack.sol` — standalone attack contract (alternative approach)
- `test/OverseerAttack.t.sol` — full test with vm.roll (passes locally)
- `targets/overseer/LESSON.md` — writeup on assumption-based vulnerabilities
