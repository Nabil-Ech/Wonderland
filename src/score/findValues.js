/**
 * Score challenge — find (v1, v2, v3) for Oracle.contribute() that forces r = 0.
 *
 * Strategy:
 *   - Set scale = oracle_balance  →  _reconstructed = balance (lower 7 bits = 0)
 *   - Search (v1, v2, v3) with v1+v2+v3 = balance until  _mixed % 128 == 0
 *   - ~1/128 probability per try, expect a hit within ~200 iterations
 *
 * Usage:
 *   ORACLE=<addr> PLAYER=<addr> RPC=http://127.0.0.1:8545 node findValues.js
 */

const { ethers } = require("ethers");

const MASK128 = (1n << 128n) - 1n;
const MASK256 = (1n << 256n) - 1n;

// ---------------------------------------------------------------------------
// Replicate Oracle._entropy update after one contribute(value) from sender
// ---------------------------------------------------------------------------
function applyContribute(entropy, value, sender) {
  // Solidity: keccak256(abi.encodePacked(_entropy, _value, msg.sender))
  // abi.encodePacked: uint256 (32 bytes) || uint256 (32 bytes) || address (20 bytes)
  const packed = ethers.solidityPacked(
    ["uint256", "uint256", "address"],
    [entropy, value, sender]
  );
  return BigInt(ethers.keccak256(packed));
}

// ---------------------------------------------------------------------------
// Replicate Oracle.getRotation() assembly
// ---------------------------------------------------------------------------
function computeRotation(entropy, count, scale, balance) {
  // key = keccak256(abi.encodePacked(entropy, count))   [both uint256, 32 bytes each]
  const packed = ethers.solidityPacked(["uint256", "uint256"], [entropy, count]);
  const key = BigInt(ethers.keccak256(packed));

  const hi = key >> 128n;
  const lo = key & MASK128;

  // mixed = hi XOR (lo << 64),  then rotate-right 7 bits (256-bit word)
  let mixed = hi ^ (lo << 64n);
  mixed = ((mixed >> 7n) | (mixed << 249n)) & MASK256;

  // _reconstructed = floor(balance/scale)*scale  XOR  balance%scale
  const reconstructed = ((balance / scale) * scale) ^ (balance % scale);

  const base = mixed ^ reconstructed;
  return base % 128n;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  const rpc     = process.env.RPC    || "http://127.0.0.1:8545";
  const oracleAddr = process.env.ORACLE;
  const playerAddr = process.env.PLAYER;

  if (!oracleAddr || !playerAddr) {
    console.error("Usage: ORACLE=<addr> PLAYER=<addr> [RPC=<url>] node findValues.js");
    process.exit(1);
  }

  const provider = new ethers.JsonRpcProvider(rpc);

  // Read oracle state from storage
  const entropy0 = BigInt(await provider.getStorage(oracleAddr, 0));
  const balance  = BigInt(await provider.getBalance(oracleAddr));
  const count0   = BigInt(await provider.getStorage(oracleAddr, 2));

  console.log("=== Oracle State ===");
  console.log("Entropy  :", "0x" + entropy0.toString(16));
  console.log("Balance  :", balance.toString(), "wei");
  console.log("Count    :", count0.toString());
  console.log("");
  console.log("Target   : scale = balance =", balance.toString());
  console.log("Searching for (v1, v2, v3) with v1+v2+v3 =", balance.toString(), "...");
  console.log("");

  // Search: v1 = iter, v2 = 1, v3 = balance - iter - 1
  // Scale is always = balance → _reconstructed = balance (lower 7 bits = 0)
  // We just need _mixed % 128 == 0
  const MAX_ITER = 10_000n;

  for (let iter = 1n; iter <= MAX_ITER; iter++) {
    const v1 = iter;
    const v2 = 1n;
    const v3 = balance - v1 - v2;

    if (v3 <= 0n) {
      console.error("v3 went non-positive — balance too small? Unlikely.");
      break;
    }

    // Simulate 3 contribute() calls from playerAddr
    let e = entropy0;
    e = applyContribute(e, v1, playerAddr);
    e = applyContribute(e, v2, playerAddr);
    e = applyContribute(e, v3, playerAddr);

    const newCount = count0 + 3n;
    const scale    = v1 + v2 + v3; // = balance

    const r = computeRotation(e, newCount, scale, balance);

    if (r === 0n) {
      console.log("=== FOUND ===");
      console.log("v1 =", v1.toString());
      console.log("v2 =", v2.toString());
      console.log("v3 =", v3.toString());
      console.log("(iterated", iter.toString(), "times)");
      console.log("");
      console.log("Next steps:");
      console.log("  1. Call oracle.contribute(" + v1 + ")");
      console.log("  2. Call oracle.contribute(" + v2 + ")");
      console.log("  3. Call oracle.contribute(" + v3 + ")");
      console.log("  4. Verify: oracle.getRotation() should return 0");
      return;
    }

    if (iter % 500n === 0n) {
      process.stdout.write("  ... tried " + iter.toString() + " combinations\r");
    }
  }

  console.log("Not found in", MAX_ITER.toString(), "iterations — check oracle state.");
}

main().catch(console.error);
