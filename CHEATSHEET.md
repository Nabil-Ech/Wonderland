# Solidity CTF Cheatsheet

## Quick Commands

```bash
# Load env
source .env

# Compile
forge build

# Compile with gas optimization (smaller bytecode = cheaper deploy)
FOUNDRY_PROFILE=ctf forge build

# Test locally
forge test -vvvv

# Test against CTF fork
forge test -vvvv --fork-url $CTF_RPC_URL

# Deploy attack script
forge script script/Attack.s.sol --rpc-url $CTF_RPC_URL --broadcast --private-key $PRIVATE_KEY

# Deploy with gas optimization
FOUNDRY_PROFILE=ctf forge script script/Attack.s.sol --rpc-url $CTF_RPC_URL --broadcast --private-key $PRIVATE_KEY

# Quick cast calls (read-only)
cast call <ADDRESS> "functionName()(uint256)" --rpc-url $CTF_RPC_URL

# Send transaction
cast send <ADDRESS> "functionName(uint256)" 42 --rpc-url $CTF_RPC_URL --private-key $PRIVATE_KEY

# Send ETH
cast send <ADDRESS> --value 1ether --rpc-url $CTF_RPC_URL --private-key $PRIVATE_KEY

# Check balance
cast balance <ADDRESS> --rpc-url $CTF_RPC_URL

# Read storage slot
cast storage <ADDRESS> <SLOT> --rpc-url $CTF_RPC_URL

# Decode/Encode
cast abi-encode "foo(uint256,address)" 42 0x...
cast abi-decode "foo()(uint256,address)" <DATA>
cast calldata "foo(uint256)" 42
cast 4byte-decode <SELECTOR>

# Get contract code
cast code <ADDRESS> --rpc-url $CTF_RPC_URL

# Keccak256
cast keccak "some string"

# Compute storage slot for mapping: keccak256(abi.encode(key, slot))
cast index address <KEY> <MAPPING_SLOT>
cast index uint256 <KEY> <MAPPING_SLOT>
```

## New Challenge Workflow

1. Read the challenge, identify the win condition (usually `isSolved()`)
2. Copy templates:
   ```bash
   cp src/AttackTemplate.sol src/ChallengeXAttack.sol
   cp script/Attack.s.sol script/ChallengeX.s.sol
   cp test/AttackTest.t.sol test/ChallengeX.t.sol
   ```
3. Paste the challenge contract into `src/` (or create an interface)
4. Write exploit in test, verify with `forge test -vvvv`
5. Deploy on-chain with `forge script`

## Common Vulnerability Patterns

### Reentrancy
- Contract calls external address before updating state
- Attack: re-enter via `receive()`/`fallback()` before state update
- Look for: `.call{value:}`, `.transfer()` BEFORE state changes

### Access Control
- Missing `onlyOwner`, wrong visibility, `tx.origin` vs `msg.sender`
- Check: `tx.origin` auth (phishable), default visibility (public)

### Integer Overflow/Underflow
- Pre-0.8.0 contracts without SafeMath
- Post-0.8.0: look for `unchecked {}` blocks

### Flash Loans
- Price manipulation via large swaps
- Borrow -> manipulate -> profit -> repay in one tx

### Delegatecall
- Storage collision between proxy and implementation
- Delegatecall to attacker-controlled address

### Self-destruct / Force-send ETH
- `selfdestruct(payable(target))` bypasses receive/fallback
- Breaks contracts relying on `address(this).balance`

### Signature Replay
- Missing nonce, missing chain ID, missing contract address in signed data
- `ecrecover` returns `address(0)` on invalid sig (check for it!)

### Storage Collision
- Proxy patterns with misaligned storage slots
- Reading "private" variables via `cast storage`

### Block Properties
- `block.timestamp` manipulation (miner can shift ~15s)
- `blockhash` only available for last 256 blocks

### ERC20 Quirks
- Missing return value (USDT-style), double-spend via approve
- Fee-on-transfer tokens, rebasing tokens

### Weak Randomness
- `blockhash`, `block.timestamp`, `block.prevrandao` are predictable
- Can be front-run or pre-computed

### Create2 / Address Prediction
- Deployed address is deterministic: `keccak256(0xff ++ sender ++ salt ++ keccak256(bytecode))`
- Can deploy to a pre-known address

## Reading "Private" Storage

Nothing on-chain is private. Read any storage slot:
```bash
# Slot 0
cast storage <CONTRACT> 0 --rpc-url $CTF_RPC_URL

# For mappings: slot = keccak256(abi.encode(key, baseSlot))
cast index uint256 <KEY> <BASE_SLOT>
# Then read that computed slot
```

## Gas Optimization Tips for Attack Contracts

- Use `FOUNDRY_PROFILE=ctf` for `optimizer_runs=1` (smallest bytecode)
- Minimize constructor logic — do setup in `exploit()` instead
- Use `abi.encodeWithSignature` for low-level calls (no interface needed)
- If bytecode size is the bottleneck, split into multiple contracts
