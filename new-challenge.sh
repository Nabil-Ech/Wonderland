#!/bin/bash
# Usage: ./new-challenge.sh <challenge-name>
# Example: ./new-challenge.sh piggy-bank
#
# Creates a challenge workspace with attack, script, and test files.
# CTF-provided contracts go in targets/<name>/ (copy them manually).

if [ -z "$1" ]; then
    echo "Usage: ./new-challenge.sh <challenge-name>"
    echo "Example: ./new-challenge.sh piggy-bank"
    exit 1
fi

NAME=$1

# Check if challenge already exists
if [ -d "src/$NAME" ] || [ -d "script/$NAME" ] || [ -d "test/$NAME" ]; then
    echo "Challenge '$NAME' already exists"
    exit 1
fi

mkdir -p "src/$NAME" "script/$NAME" "test/$NAME" "targets/$NAME/src"

# Attack contract
cat > "src/$NAME/Attack.sol" << 'SOLEOF'
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
cat > "script/$NAME/Attack.s.sol" << SOLEOF
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "src/$NAME/Attack.sol";

contract AttackScript is Script {
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
cat > "test/$NAME/Attack.t.sol" << SOLEOF
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "src/$NAME/Attack.sol";

contract AttackTest is Test {
    function test_exploit() public {
        // vm.startPrank(vm.envAddress("PLAYER_ADDRESS"));

        // YOUR EXPLOIT HERE

        // assertTrue(IChallenge(target).isSolved());
        // vm.stopPrank();
    }
}
SOLEOF

# Placeholder for CTF-provided contracts
cat > "targets/$NAME/challenge.md" << EOF
# $NAME

## Target Address
\`TODO\`

## Win Condition
TODO
EOF

echo "Created challenge workspace for '$NAME':"
echo ""
echo "  targets/$NAME/       — paste CTF-provided contracts here"
echo "  src/$NAME/Attack.sol — write your attack contract"
echo "  script/$NAME/Attack.s.sol — deploy script"
echo "  test/$NAME/Attack.t.sol   — test file"
echo ""
echo "Commands:"
echo "  forge test -vvvv --match-path test/$NAME/Attack.t.sol"
echo "  forge test -vvvv --match-path test/$NAME/Attack.t.sol --fork-url \$CTF_RPC_URL"
echo "  forge script script/$NAME/Attack.s.sol --rpc-url \$CTF_RPC_URL --broadcast --private-key \$PRIVATE_KEY"
