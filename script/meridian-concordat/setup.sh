#!/usr/bin/env bash
set -uo pipefail

# ═══════════════════════════════════════════════════════
# Meridian Concordat — Anvil Setup with EIP-7702
# Usage: bash script/meridian_setup.sh
# ═══════════════════════════════════════════════════════

# Was: running from script/meridian-concordat/ broke forge paths — must cd to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

RPC="http://127.0.0.1:8545"

# Anvil default accounts
SYSTEM_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
PLAYER_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
BOREAS_KEY="0x5de4111afe1508cf82f0b5e28cd0ca7e1a02b8e50a2b27a548e6d371b44b8b14"
HELIX_KEY="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
VORTAN_KEY="0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a"
DRIFT_KEY="0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba"
THALIAN_KEY="0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e"
KAEL_KEY="0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356"
AXIOM_KEY="0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97"

SYSTEM=$(cast wallet address $SYSTEM_KEY)
PLAYER=$(cast wallet address $PLAYER_KEY)
BOREAS=$(cast wallet address $BOREAS_KEY)
HELIX=$(cast wallet address $HELIX_KEY)
VORTAN=$(cast wallet address $VORTAN_KEY)
DRIFT=$(cast wallet address $DRIFT_KEY)
THALIAN=$(cast wallet address $THALIAN_KEY)
KAEL=$(cast wallet address $KAEL_KEY)
AXIOM=$(cast wallet address $AXIOM_KEY)

echo "=================================================="
echo " Meridian Concordat — Anvil EIP-7702 Setup"
echo "=================================================="
echo ""

# ──────────────────────────────────────────────────────
# 1. Start anvil with Prague hardfork (EIP-7702 support)
# ──────────────────────────────────────────────────────
echo "[1/5] Starting anvil --hardfork prague ..."
# Was: no cleanup of old anvil → "Address already in use" error if anvil already running
# Was: sleep 2 wasn't enough — anvil not ready when forge tried to deploy
pkill -f "anvil --hardfork prague" 2>/dev/null || true
sleep 1
anvil --hardfork prague --silent &
ANVIL_PID=$!
# Wait until anvil is actually listening
for i in $(seq 1 10); do
  cast chain-id --rpc-url $RPC 2>/dev/null && break
  sleep 1
done
echo "  Anvil PID: $ANVIL_PID"

# ──────────────────────────────────────────────────────
# 2. Deploy Challenge contract
# ──────────────────────────────────────────────────────
echo "[2/5] Deploying Challenge contract ..."
DEPLOY_OUTPUT=$(forge script script/meridian-concordat/Setup.s.sol \
  --rpc-url $RPC --broadcast --skip-simulation 2>&1)

CHALLENGE=$(echo "$DEPLOY_OUTPUT" | grep "CHALLENGE=" | sed 's/.*CHALLENGE=//')
if [[ -z "$CHALLENGE" ]]; then
  echo "  ERROR: Challenge deployment failed. Output:"
  echo "$DEPLOY_OUTPUT"
  kill $ANVIL_PID 2>/dev/null
  exit 1
fi
echo "  Challenge: $CHALLENGE"

# Read implementation addresses from Challenge
LEGACY_OPS=$(cast call $CHALLENGE "LEGACY_OPS()(address)" --rpc-url $RPC)
BATCH_EXECUTOR=$(cast call $CHALLENGE "BATCH_EXECUTOR()(address)" --rpc-url $RPC)
SAFE_WALLET=$(cast call $CHALLENGE "SAFE_WALLET()(address)" --rpc-url $RPC)
CANNON_GUARD=$(cast call $CHALLENGE "CANNON_GUARD()(address)" --rpc-url $RPC)
ACCOUNT_RECOVERY_V1=$(cast call $CHALLENGE "ACCOUNT_RECOVERY_V1()(address)" --rpc-url $RPC)
ACCOUNT_RECOVERY_V2=$(cast call $CHALLENGE "ACCOUNT_RECOVERY_V2()(address)" --rpc-url $RPC)
SHARED_ESCROW=$(cast call $CHALLENGE "SHARED_ESCROW()(address)" --rpc-url $RPC)
GOVERNANCE=$(cast call $CHALLENGE "GOVERNANCE()(address)" --rpc-url $RPC)
SOVEREIGN_AI=$(cast call $CHALLENGE "SOVEREIGN_AI()(address)" --rpc-url $RPC)
MRC=$(cast call $CHALLENGE "MRC()(address)" --rpc-url $RPC)

echo "  MRC:       $MRC"

# ──────────────────────────────────────────────────────
# 3. Set EIP-7702 delegations via anvil_setCode
#    Format: 0xef0100 + 20-byte impl address
# ──────────────────────────────────────────────────────
echo "[3/5] Setting EIP-7702 delegations ..."

set_delegation() {
  local eoa=$1
  local impl=$2
  local name=$3
  # Strip 0x prefix from impl, build ef0100 designator
  local impl_hex="${impl#0x}"
  cast rpc anvil_setCode "$eoa" "0xef0100${impl_hex}" --rpc-url $RPC > /dev/null
  echo "  $name ($eoa) -> ${impl}"
}

# BOREAS: first delegate to V1 (for init), will switch to V2 after
set_delegation $BOREAS $ACCOUNT_RECOVERY_V1 "BOREAS [temp V1]"

# HELIX -> SafeSmartWallet
set_delegation $HELIX $SAFE_WALLET "HELIX"

# VORTAN -> LegacyReserveOps
set_delegation $VORTAN $LEGACY_OPS "VORTAN"

# DRIFT -> BatchExecutor
set_delegation $DRIFT $BATCH_EXECUTOR "DRIFT"

# THALIAN -> SharedEscrow
set_delegation $THALIAN $SHARED_ESCROW "THALIAN"

# KAEL -> GovernanceModule
set_delegation $KAEL $GOVERNANCE "KAEL"

# AXIOM -> SovereignAI
set_delegation $AXIOM $SOVEREIGN_AI "AXIOM"

# ──────────────────────────────────────────────────────
# 4. Initialize each station
# ──────────────────────────────────────────────────────
echo "[4/5] Initializing stations ..."

# BOREAS: init with V1 (consumes Initializable version 1)
cast send $BOREAS "initialize(address,address[])" \
  $SYSTEM "[$SYSTEM]" \
  --private-key $SYSTEM_KEY --rpc-url $RPC > /dev/null 2>&1
echo "  BOREAS initialized with V1 (version 1 consumed)"

# Now switch BOREAS to V2 (storage preserved, _initialized = 1)
set_delegation $BOREAS $ACCOUNT_RECOVERY_V2 "BOREAS [final V2]"
echo "  BOREAS re-delegated to V2 (reinitializer(2) now callable)"

# HELIX: SafeSmartWallet.initialize(owner, guard)
cast send $HELIX "initialize(address,address)" \
  $SYSTEM $CANNON_GUARD \
  --private-key $SYSTEM_KEY --rpc-url $RPC > /dev/null 2>&1
echo "  HELIX initialized (guard = CannonGuard)"

# Create capsule for HELIX: pre-approves MRC.mint()
# Was: log-parsing extracted topic[1] (wallet) instead of topic[2] (capsule)
cast send $CANNON_GUARD \
  "createCapsule(address,address,bytes4,uint256)" \
  $HELIX $MRC "0x40c10f19" 0 \
  --private-key $SYSTEM_KEY --rpc-url $RPC > /dev/null 2>&1
# Query the guard directly — simpler and reliable
CAPSULE=$(cast call $CANNON_GUARD "getCapsules(address)(address[])" $HELIX --rpc-url $RPC 2>/dev/null | tr -d '[]' | xargs | cut -d' ' -f1)
echo "  Capsule created: $CAPSULE"

# VORTAN: LegacyReserveOps.initialize(admin, partner)
cast send $VORTAN "initialize(address,address)" \
  $SYSTEM $THALIAN \
  --private-key $SYSTEM_KEY --rpc-url $RPC > /dev/null 2>&1
echo "  VORTAN initialized (partner = THALIAN)"

# DRIFT: BatchExecutor.initialize(owner)
cast send $DRIFT "initialize(address)" \
  $SYSTEM \
  --private-key $SYSTEM_KEY --rpc-url $RPC > /dev/null 2>&1
echo "  DRIFT initialized"

# THALIAN: SharedEscrow.initialize(owner, partner)
cast send $THALIAN "initialize(address,address)" \
  $SYSTEM $VORTAN \
  --private-key $SYSTEM_KEY --rpc-url $RPC > /dev/null 2>&1
echo "  THALIAN initialized (partner = VORTAN)"

# KAEL: GovernanceModule.initialize(owner, council, quorum)
COUNCIL_A="0x0000000000000000000000000000000000000C01"
COUNCIL_B="0x0000000000000000000000000000000000000C02"
cast send $KAEL "initialize(address,address[],uint256)" \
  $SYSTEM "[$SYSTEM,$COUNCIL_A,$COUNCIL_B]" 2 \
  --private-key $SYSTEM_KEY --rpc-url $RPC > /dev/null 2>&1
echo "  KAEL initialized (council of 3, quorum = 2)"

# AXIOM: SovereignAI.initialize(authority=itself)
cast send $AXIOM "initialize(address)" \
  $AXIOM \
  --private-key $SYSTEM_KEY --rpc-url $RPC > /dev/null 2>&1
echo "  AXIOM initialized (authority = itself)"

# AXIOM: declareIndependence (no access control)
cast send $AXIOM "declareIndependence()" \
  --private-key $SYSTEM_KEY --rpc-url $RPC > /dev/null 2>&1
echo "  AXIOM independence declared"

# AXIOM: configureTreaty (deployer = system)
cast send $AXIOM "configureTreaty(address,uint256)" \
  $MRC $(cast --to-wei 150000) \
  --private-key $SYSTEM_KEY --rpc-url $RPC > /dev/null 2>&1
echo "  AXIOM treaty configured (150k MRC allocation)"

# ──────────────────────────────────────────────────────
# 5. Write .env so user can source variables in terminal
# ──────────────────────────────────────────────────────
ENV_FILE="$PROJECT_ROOT/script/meridian-concordat/.env"
cat > "$ENV_FILE" <<ENVEOF
# Meridian Concordat — generated by setup.sh
# Was: missing export — source'd vars weren't visible to child processes (forge)
export RPC="http://127.0.0.1:8545"

export CHALLENGE="$CHALLENGE"
export MRC="$MRC"
export CANNON_GUARD="$CANNON_GUARD"
export CAPSULE="$CAPSULE"

export PLAYER="$PLAYER"
export PLAYER_KEY="$PLAYER_KEY"
export SYSTEM="$SYSTEM"
export SYSTEM_KEY="$SYSTEM_KEY"

export BOREAS="$BOREAS"
export HELIX="$HELIX"
export VORTAN="$VORTAN"
export DRIFT="$DRIFT"
export THALIAN="$THALIAN"
export KAEL="$KAEL"
export AXIOM="$AXIOM"

export BOREAS_KEY="$BOREAS_KEY"
export HELIX_KEY="$HELIX_KEY"
export VORTAN_KEY="$VORTAN_KEY"
export DRIFT_KEY="$DRIFT_KEY"
export THALIAN_KEY="$THALIAN_KEY"
export KAEL_KEY="$KAEL_KEY"
export AXIOM_KEY="$AXIOM_KEY"
ENVEOF
echo "  .env written to: $ENV_FILE"
echo "  Usage: source script/meridian-concordat/.env"
echo ""

# ──────────────────────────────────────────────────────
# 6. Print summary
# ──────────────────────────────────────────────────────
echo ""
echo "=================================================="
echo " SETUP COMPLETE — Meridian Concordat on Anvil"
echo "=================================================="
echo ""
echo "  Challenge:    $CHALLENGE"
echo "  MRC:          $MRC"
echo "  CannonGuard:  $CANNON_GUARD"
echo "  Capsule:      $CAPSULE"
echo ""
echo "  PLAYER:       $PLAYER"
echo "  SYSTEM:       $SYSTEM"
echo ""
echo "  BOREAS:       $BOREAS    (mintCap: 500k)"
echo "  HELIX:        $HELIX    (mintCap: 500k)"
echo "  VORTAN:       $VORTAN    (mintCap: 200k)"
echo "  DRIFT:        $DRIFT    (mintCap: 0)"
echo "  THALIAN:      $THALIAN    (mintCap: 200k)"
echo "  KAEL:         $KAEL    (mintCap: 300k)"
echo "  AXIOM:        $AXIOM    (mintCap: 300k)"
echo ""
echo "=================================================="
echo " HOW TO INSPECT"
echo "=================================================="
echo ""
echo "  # Check which contract an EOA delegates to:"
echo "  cast code $BOREAS --rpc-url $RPC"
echo "  # Returns: 0xef0100<impl_address>"
echo "  #          ^^^^^^ EIP-7702 prefix"
echo "  #                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ implementation"
echo ""
echo "  # Decode the impl address from delegation:"
echo "  cast code $BOREAS --rpc-url $RPC | cut -c9-"
echo "  # Compare with:"
echo "  cast call $CHALLENGE 'ACCOUNT_RECOVERY_V2()(address)' --rpc-url $RPC"
echo ""
echo "  # Read station state:"
echo "  cast call $BOREAS 'owner()(address)' --rpc-url $RPC"
echo "  cast call $HELIX 'guard()(address)' --rpc-url $RPC"
echo "  cast call $AXIOM 'manifesto()(string)' --rpc-url $RPC"
echo ""
echo "  # Check mint caps:"
echo "  cast call $MRC 'mintCap(address)(uint256)' $BOREAS --rpc-url $RPC"
echo ""
echo "  # Player private key:"
echo "  $PLAYER_KEY"
echo ""
echo "  # Win condition: MRC.balanceOf(player) >= 1,150,000"
echo "  cast call $MRC 'isSolved()(bool)' --rpc-url $RPC"
echo ""
echo "  Anvil running in background (PID: $ANVIL_PID)"
echo "  Kill with: kill $ANVIL_PID"
echo ""
