# Wonderland CTF — Cannes 2026

Solidity CTF challenge solutions from the Wonderland CTF event.

## Challenges

| # | Challenge | Status | Vulnerability | Files |
|---|-----------|--------|---------------|-------|
| 1 | **Sentinel** | Solved | Metamorphic CREATE2 + selfdestruct | [targets](targets/sentinel/) / [attack](src/sentinel/) / [script](script/sentinel/) |
| 2 | **Blackout** | Solved | Dirty calldataload upper-bytes bypass | [targets](targets/blackout/) / [attack](src/blackout/) / [script](script/blackout/) |
| 3 | **Score** | Solved | Oracle gas manipulation + XOR solve | [targets](targets/score/) / [attack](src/score/) / [script](script/score/) / [test](test/score/) |
| 4 | **Overseer** | Solved | Badge-transfer governance exploit | [targets](targets/overseer/) / [attack](src/overseer/) / [script](script/overseer/) / [test](test/overseer/) |
| 5 | **Puzzle Wallet** | Solved | Proxy storage collision + delegatecall | [attack](src/puzzle-wallet/) / [script](script/puzzle-wallet/) / [test](test/puzzle-wallet/) |
| 6 | **Meridian Concordat** | In Progress | EIP-7702 multi-station exploit | [targets](targets/meridian-concordat/) / [attack](src/meridian-concordat/) / [script](script/meridian-concordat/) / [test](test/meridian-concordat/) |
| 7 | **ScrambledZoo** | Unsolved | Physical / IRL challenge | [targets](targets/scrambledZoo/) |
| 8 | **StakeHouse** | Unsolved | TBD | [targets](targets/stakehouse/) |
| 9 | **Lucky Guess** | Unsolved | Noir ZK circuit | [targets](targets/lucky_guess/) |
| 10 | **UECallNFT** | Unsolved | TBD | [targets](targets/uecallnft/) |

## Repo Structure

```
targets/<name>/          CTF-provided contracts (read-only, as given by organizers)
src/<name>/              Attack contracts for that challenge
script/<name>/           Deploy / setup scripts
test/<name>/             Local tests (forge test)
challenges/              Walkthroughs and notes
templates/               Blank templates for new challenges
```

## Quick Start

```bash
# Add a new challenge workspace
./new-challenge.sh <challenge-name>

# Build everything
forge build

# Test a specific challenge
forge test -vvvv --match-path test/<name>/Attack.t.sol

# Test against CTF fork
forge test -vvvv --match-path test/<name>/Attack.t.sol --fork-url $CTF_RPC_URL

# Deploy attack on-chain
forge script script/<name>/Attack.s.sol --rpc-url $CTF_RPC_URL --broadcast --private-key $PRIVATE_KEY

# Gas-optimized deploy (smaller bytecode)
FOUNDRY_PROFILE=ctf forge script script/<name>/Attack.s.sol --rpc-url $CTF_RPC_URL --broadcast --private-key $PRIVATE_KEY
```

## References

- [GUIDE.md](GUIDE.md) — Full CTF workflow tutorial (recon, exploit, deploy)
- [CHEATSHEET.md](CHEATSHEET.md) — Quick reference for cast/forge commands
