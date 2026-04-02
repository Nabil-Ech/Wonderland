#!/bin/bash
# Usage: ./new-challenge.sh <challenge-name>
# Example: ./new-challenge.sh piggy-bank
#
# Creates a full challenge workspace with all template files.
# Each team member works in their own challenge folder — no conflicts.

if [ -z "$1" ]; then
    echo "Usage: ./new-challenge.sh <challenge-name>"
    echo "Example: ./new-challenge.sh piggy-bank"
    exit 1
fi

NAME=$1
DIR="challenges/$NAME"

if [ -d "$DIR" ]; then
    echo "Challenge '$NAME' already exists at $DIR"
    exit 1
fi

mkdir -p "$DIR"

# Challenge source (paste the vulnerable contract here)
cat > "$DIR/Challenge.sol" << 'SOLEOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// PASTE THE CHALLENGE CONTRACT SOURCE CODE HERE

// interface IChallenge {
//     function isSolved() external view returns (bool);
// }
SOLEOF

# Attack contract
cat > "$DIR/Attack.sol" << 'SOLEOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Attack {
    address public target;

    constructor(address _target) {
        target = _target;
    }

    function exploit() external payable {
        // YOUR EXPLOIT HERE
    }

    receive() external payable {}
}
SOLEOF

# Deploy script
cat > "$DIR/Solve.s.sol" << 'SOLEOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

contract SolveScript is Script {
    function run() external {
        vm.startBroadcast();

        // address target = 0x...;
        // Attack attack = new Attack(target);
        // attack.exploit();

        vm.stopBroadcast();
    }
}
SOLEOF

# Test
cat > "$DIR/Solve.t.sol" << 'SOLEOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract SolveTest is Test {
    function test_exploit() public {
        // address target = 0x...;
        // vm.startPrank(vm.envAddress("PLAYER_ADDRESS"));

        // YOUR EXPLOIT HERE

        // assertTrue(IChallenge(target).isSolved());
        // vm.stopPrank();
    }
}
SOLEOF

# Notes file
cat > "$DIR/NOTES.md" << EOF
# Challenge: $NAME

## Target Address
\`TODO\`

## Vulnerability Type
TODO

## Analysis
-

## Solution
-

## Key Takeaway
-
EOF

echo "✓ Created challenge workspace at $DIR/"
echo ""
echo "Files:"
echo "  $DIR/Challenge.sol  — paste the challenge source here"
echo "  $DIR/Attack.sol     — write your attack contract"
echo "  $DIR/Solve.s.sol    — deploy script"
echo "  $DIR/Solve.t.sol    — test file"
echo "  $DIR/NOTES.md       — your analysis notes"
echo ""
echo "Commands:"
echo "  forge test -vvvv --match-path $DIR/Solve.t.sol"
echo "  forge test -vvvv --match-path $DIR/Solve.t.sol --fork-url \$CTF_RPC_URL"
echo "  forge script $DIR/Solve.s.sol --rpc-url \$CTF_RPC_URL --broadcast --private-key \$PRIVATE_KEY"
