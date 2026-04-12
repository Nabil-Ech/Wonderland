/**
 * Score challenge — full attack in one script.
 *
 * Steps:
 *   1. Find (v1, v2, v3) with sum = oracle balance → forces r = 0
 *   2. Send 3 contribute() txs
 *   3. Build GF(2) basis from elements, solve XOR for target
 *   4. Compute Score's gas limit, calibrate tx gas via simulation
 *   5. Send solve()
 *
 * Usage:
 *   ORACLE=<addr> SCORE=<addr> PLAYER=<addr> PRIVATE_KEY=<key> [RPC=<url>] node attack.js
 */

const { ethers } = require("ethers");

const MASK256 = (1n << 256n) - 1n;
const MASK128 = (1n << 128n) - 1n;

// ─── Oracle helpers ────────────────────────────────────────────────────────

// Replicates: _entropy = keccak256(abi.encodePacked(_entropy, _value, msg.sender))
function applyContribute(entropy, value, sender) {
    const packed = ethers.solidityPacked(
        ["uint256", "uint256", "address"],
        [entropy, value, sender]
    );
    return BigInt(ethers.keccak256(packed));
}

// Replicates Oracle.getRotation() assembly
function computeRotation(entropy, count, scale, balance) {
    const packed = ethers.solidityPacked(["uint256", "uint256"], [entropy, count]);
    const key    = BigInt(ethers.keccak256(packed));

    const hi  = key >> 128n;
    const lo  = key & MASK128;
    let mixed = hi ^ (lo << 64n);
    mixed = ((mixed >> 7n) | (mixed << 249n)) & MASK256;   // rotate-right 7

    const reconstructed = ((balance / scale) * scale) ^ (balance % scale);
    return (mixed ^ reconstructed) % 128n;
}

// Search v1=iter, v2=1, v3=balance-iter-1 (so scale always = balance)
// balance % 128 = 0  →  need mixed % 128 = 0  →  ~1/128 chance per try
function findContribValues(entropy0, balance, count0, player) {
    console.log("Searching for (v1, v2, v3) with sum =", balance.toString(), "...");
    for (let iter = 1n; iter <= 10_000n; iter++) {
        const v1 = iter;
        const v2 = 1n;
        const v3 = balance - v1 - v2;
        if (v3 <= 0n) break;

        let e = entropy0;
        e = applyContribute(e, v1, player);
        e = applyContribute(e, v2, player);
        e = applyContribute(e, v3, player);

        if (computeRotation(e, count0 + 3n, balance, balance) === 0n) {
            console.log(`Found in ${iter} iterations: v1=${v1}  v2=${v2}  v3=${v3}`);
            return { v1, v2, v3 };
        }
    }
    throw new Error("No values found in 10k iterations");
}

// ─── GF(2) XOR solver ─────────────────────────────────────────────────────
//
// We have: target = keccak256(seed, blockNumber)
//          e[i]   = keccak256(seed, i, blockNumber)
// Goal   : find subset S such that XOR of e[i] for i in S = target
//
// Method : Gaussian elimination over GF(2)
//   - Build a "basis" of 256 linearly independent vectors
//   - Each basis slot b holds a value whose highest set bit is exactly b
//   - Insert each e[i]: eliminate its highest bit using existing basis entries
//     If a free slot is found, store it there (record which original index)
//   - Then reduce target through the same basis → the recorded indices are the answer

function getElement(seed, index, blockNum) {
    return BigInt(ethers.keccak256(
        ethers.solidityPacked(["bytes32", "uint256", "uint256"], [seed, index, blockNum])
    ));
}

function getTarget(seed, blockNum) {
    return BigInt(ethers.keccak256(
        ethers.solidityPacked(["bytes32", "uint256"], [seed, blockNum])
    ));
}

// How many elements to try. 256 random 256-bit vectors only span GF(2)^256
// with ~29% probability. Each extra element roughly halves the failure chance.
// 400 elements gives P(failure) < 10^-40.
const NUM_ELEMENTS = 400;

function gf2Solve(seed, blockNum) {
    const target = getTarget(seed, blockNum);

    // basisValue[b] = the value stored at bit position b
    // basisMask[b]  = bitmask (arbitrary-precision BigInt) tracking which original indices
    const basisValue = new Array(256).fill(0n);
    const basisMask  = new Array(256).fill(0n);

    for (let i = 0; i < NUM_ELEMENTS; i++) {
        let v = getElement(seed, i, blockNum);  // random 256-bit hash
        let m = 1n << BigInt(i);                // tracks this original index

        // Walk down from highest bit, eliminating using existing basis entries
        for (let bit = 255; bit >= 0; bit--) {
            if (!((v >> BigInt(bit)) & 1n)) continue;   // bit not set, skip

            if (basisValue[bit] === 0n) {
                basisValue[bit] = v;    // free slot — store here
                basisMask[bit]  = m;
                break;
            }
            // Bit already covered — eliminate it and keep going
            v ^= basisValue[bit];
            m ^= basisMask[bit];
        }
        // If v == 0 here, e[i] was linearly dependent (fine, skip)
    }

    // Reduce target through the basis to find which entries to XOR
    let remaining    = target;
    let solutionMask = 0n;

    for (let bit = 255; bit >= 0; bit--) {
        if (!((remaining >> BigInt(bit)) & 1n)) continue;
        if (basisValue[bit] === 0n) throw new Error(`No basis vector at bit ${bit}`);
        remaining    ^= basisValue[bit];
        solutionMask ^= basisMask[bit];
    }
    if (remaining !== 0n) throw new Error("GF2: no solution (basis incomplete)");

    // Collect the indices whose bits are set in solutionMask
    const indices = [];
    for (let i = 0; i < NUM_ELEMENTS; i++) {
        if ((solutionMask >> BigInt(i)) & 1n) indices.push(i);
    }
    return indices;
}

// ─── Gas calibration ──────────────────────────────────────────────────────
//
// Score.solve() ends with:
//   gasLimit = keccak256(seed, block.number) % 40000 + 10000
//   if gas() > gasLimit → revert 0x021b0014
//
// We need gas_remaining_at_check ≤ gasLimit, i.e.:
//   G_tx ≤ intrinsic + C_execution + gasLimitScore
//
// Strategy:
//   1. eth_estimateGas at "pending" block → gives minimum G to run solve() successfully.
//      Because the minimum success is when remaining_at_check ≈ 0 ≤ gasLimitScore.
//      This minimum ≈ intrinsic + C_execution.
//   2. Add gasLimitScore/2 as buffer → remaining ≈ gasLimitScore/2, well under the limit.
//
// Note: getElement() is a public function called internally (JUMP, not CALL),
// so per-index cost is ~200 gas, not 5000. estimateGas handles this automatically.

function scoreGasLimit(seed, blockNum) {
    const hash = BigInt(ethers.keccak256(
        ethers.solidityPacked(["bytes32", "uint256"], [seed, blockNum])
    ));
    return Number(hash % 40000n) + 10000;
}

// G has three zones as it increases:
//   too_low  → OOG before reaching gas check  (no revert data)
//   success  → gas remaining ≤ gasLimitScore  (width = gasLimitScore, 10k–50k)
//   too_high → gas check fires 0x021b0014     (remaining > gasLimitScore)
//
// eth_estimateGas always tries the max gas first (block limit ~30M) → too_high
// → it gives up immediately. So we must binary-search manually.

// 0x021b0014 = hardcoded bytes in Score's gas-check assembly revert
// 0x182067d6 = Score_WrongSolution() — indices don't match the block (block advanced)
const GAS_CHECK_SIG   = "021b0014";
const WRONG_SOL_SIG   = "182067d6";

async function tryGas(provider, scoreAddr, calldata, G) {
    try {
        // blockTag inside the tx object — this is the ethers v6 API
        await provider.call({ to: scoreAddr, data: calldata, gasLimit: G, blockTag: "pending" });
        return "success";
    } catch (e) {
        const raw = e.data ?? e.info?.error?.data ?? "";
        const hex = typeof raw === "string" ? raw : "";
        if (hex.includes(GAS_CHECK_SIG)) return "too_high";
        if (hex.includes(WRONG_SOL_SIG)) return "wrong_block"; // pending block advanced
        return "too_low"; // OOG
    }
}

async function computeGas(provider, scoreAddr, calldata, gasLimitScore) {
    // Binary search: find the too_low → success boundary.
    // The success window is gasLimitScore wide (~10k–50k).
    let lo = 30_000;    // always too_low for any realistic solve()
    let hi = 500_000;   // always too_high (gas check fires with huge remaining)

    // Verify bounds
    const hiRes = await tryGas(provider, scoreAddr, calldata, hi);
    const loRes = await tryGas(provider, scoreAddr, calldata, lo);
    console.log(`Bound check: lo(${lo})=${loRes}  hi(${hi})=${hiRes}`);

    if (hiRes === "wrong_block" || loRes === "wrong_block")
        throw new Error("Pending block advanced mid-search — re-run the script");
    if (hiRes === "success") return BigInt(hi);
    if (loRes !== "too_low")  throw new Error(`Unexpected lo result: ${loRes}`);
    if (hiRes !== "too_high") throw new Error(`Unexpected hi result: ${hiRes}`);

    // Binary search narrows to within ~1000 gas of the too_low→success boundary
    while (hi - lo > 1_000) {
        const mid = Math.floor((lo + hi) / 2);
        const res = await tryGas(provider, scoreAddr, calldata, mid);
        if      (res === "too_low")   lo = mid;
        else if (res === "success")  { console.log(`Found success at G=${mid}`); return BigInt(mid); }
        else if (res === "wrong_block") throw new Error("Pending block advanced — re-run");
        else                          hi = mid;  // too_high: back off
    }

    // Linear scan of the remaining narrow window
    for (let G = lo; G <= hi; G += 50) {
        const res = await tryGas(provider, scoreAddr, calldata, G);
        if (res === "success")    { console.log(`Found success at G=${G}`); return BigInt(G); }
        if (res === "too_high")   break;
        if (res === "wrong_block") throw new Error("Pending block advanced — re-run");
    }

    throw new Error("Gas search failed — success window not found in [30k, 500k]");
}

// ─── ABIs ─────────────────────────────────────────────────────────────────

const ORACLE_ABI = [
    "function contribute(uint256 _value) external payable",
    "function getRotation() external view returns (uint256)",
];
const SCORE_ABI = [
    "function solve(uint256[] calldata _indices) external",
    "function seed() external view returns (bytes32)",
    "function isSolved() external view returns (bool)",
];

// ─── Main ─────────────────────────────────────────────────────────────────

async function main() {
    const rpc        = process.env.RPC         || "http://127.0.0.1:8545";
    const oracleAddr = process.env.ORACLE;
    const scoreAddr  = process.env.SCORE;
    const playerAddr = process.env.PLAYER;
    const privateKey = process.env.PRIVATE_KEY;

    if (!oracleAddr || !scoreAddr || !playerAddr || !privateKey) {
        console.error("Usage: ORACLE=<addr> SCORE=<addr> PLAYER=<addr> PRIVATE_KEY=<pk> [RPC=<url>] node attack.js");
        process.exit(1);
    }

    const provider = new ethers.JsonRpcProvider(rpc);
    const signer   = new ethers.Wallet(privateKey, provider);
    const oracle   = new ethers.Contract(oracleAddr, ORACLE_ABI, signer);
    const score    = new ethers.Contract(scoreAddr,  SCORE_ABI,  signer);

    // ── 1. Read state ──────────────────────────────────────────────────────
    const entropy0 = BigInt(await provider.getStorage(oracleAddr, 0));
    const balance  = BigInt(await provider.getBalance(oracleAddr));
    const count0   = BigInt(await provider.getStorage(oracleAddr, 2));
    const seed     = await score.seed();

    console.log("=== Oracle ===");
    console.log("Balance :", ethers.formatEther(balance), "ETH");
    console.log("Count   :", count0.toString());

    // ── 2. Find (v1, v2, v3) ──────────────────────────────────────────────
    const { v1, v2, v3 } = findContribValues(entropy0, balance, count0, playerAddr);

    // ── 3. Contribute ─────────────────────────────────────────────────────
    console.log("\n=== Contributing ===");
    await (await oracle.contribute(v1)).wait();
    console.log("contribute(v1) mined");
    await (await oracle.contribute(v2)).wait();
    console.log("contribute(v2) mined");
    await (await oracle.contribute(v3)).wait();
    console.log("contribute(v3) mined");

    const r = await oracle.getRotation();
    console.log("getRotation() =", r.toString());
    if (r !== 0n) throw new Error(`Expected r=0, got r=${r}`);

    // ── 4. Get the pending block number ───────────────────────────────────────
    // "pending" is the block our tx will land in.
    // We use it for GF2 and for eth_estimateGas so both are at the same block.number.
    const pendingBlock = await provider.send("eth_getBlockByNumber", ["pending", false]);
    const solveBlock   = Number(pendingBlock.number);
    const currentBlock = solveBlock - 1;
    console.log(`\nConfirmed block: ${currentBlock} — pending (solve) block: ${solveBlock}`);

    // ── 5. GF(2) solve ────────────────────────────────────────────────────
    console.log("Building GF(2) basis and solving...");
    const indices = gf2Solve(seed, solveBlock);
    console.log(`Solution: ${indices.length} indices — [${indices.join(", ")}]`);

    // ── 6. Verify solution locally ─────────────────────────────────────────
    const target = getTarget(seed, solveBlock);
    let check = 0n;
    for (const i of indices) check ^= getElement(seed, i, solveBlock);
    if (check !== target) throw new Error("BUG: local XOR check failed");
    console.log("Local XOR check: OK");

    // ── 7. Gas calibration ────────────────────────────────────────────────
    const gasLimitScore = scoreGasLimit(seed, solveBlock);
    console.log(`\nScore gasLimit = ${gasLimitScore}`);

    const iface    = new ethers.Interface(SCORE_ABI);
    const calldata = iface.encodeFunctionData("solve", [indices]);

    const gasToUse = await computeGas(provider, scoreAddr, calldata, gasLimitScore);

    // ── 8. Send solve() ───────────────────────────────────────────────────
    console.log("\n=== Sending solve() ===");
    const tx      = await signer.sendTransaction({ to: scoreAddr, data: calldata, gasLimit: gasToUse });
    const receipt = await tx.wait();
    console.log("Status  :", receipt.status === 1 ? "SUCCESS ✓" : "FAILED ✗");
    console.log("Gas used:", receipt.gasUsed.toString());
    console.log("Block   :", receipt.blockNumber);

    // ── 9. Verify ─────────────────────────────────────────────────────────
    const solved = await score.isSolved();
    console.log("\nisSolved():", solved);
    if (solved) console.log("CHALLENGE SOLVED!");
    else        console.log("Not solved — gas calibration may need adjustment");
}

main().catch(console.error);
