# Bytecode & Immutables — Quick Reference

## Two stages of bytecode

1. **Creation (init) bytecode** — runs the constructor. Immutables are placeholders (zeros).
2. **Deployed (runtime) bytecode** — after constructor finishes, Solidity replaces placeholders with actual immutable values as `PUSH32` instructions.

## Reading bytecode on-chain

- **`EXTCODECOPY`** — returns runtime bytecode (includes immutables baked in)
- **`EXTCODESIZE`** — returns size of runtime bytecode
- **`EXTCODEHASH`** — keccak256 of runtime bytecode (includes immutables)
- **`cast code <addr>`** — foundry shortcut for EXTCODECOPY

## Why immutables are cheap

- Storage read (`SLOAD`) = 2100 gas (cold)
- Immutable read (`PUSH32`) = 3 gas
- Tradeoff: can only set once, in the constructor

## CREATE2 and immutables

```
address = keccak256(0xff ++ deployer ++ salt ++ keccak256(initcode))
```

- `initcode` = creation bytecode + constructor args appended
- Immutables are still **placeholders** in initcode (not baked yet)
- BUT constructor args are part of initcode, so changing a constructor arg (that sets an immutable) **changes the initcode hash** → **changes the CREATE2 address**
- So: different immutable values → different constructor args → different CREATE2 address (indirectly)

## ERC-7201 namespaced storage (OZ v5)

- `Initializable` does NOT use slot 0 anymore
- Uses a high slot: `keccak256("openzeppelin.storage.Initializable") - 1) & ~0xff`
- Slot = `0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00`
- Child contract variables (like `owner`) start at slot 0 as expected
