# Overseer — Lesson Learned

## The Root Cause: False Assumptions

The vulnerability here isn't a logic bug — every function works exactly as intended. The real issue is that **one contract's assumptions don't match another contract's guarantees**.

### The Assumption

The Guild assumes that a **badge is a permanent, non-transferable identity**. It builds its entire permission system on this: ranks are mapped to badges, votes are counted per address, and it never considers that the badge behind an address could change — or that two different addresses could sequentially hold the same badge.

### The Reality

The Overseer allows badge transfers via `proposeBadgeChange` / `acceptBadgeChange`. A badge can move from one address to another. The Guild was never told this. It never asked.

### Why This Matters Beyond This CTF

This pattern — **correct logic built on false assumptions** — is arguably the #1 root cause of real-world smart contract exploits:

- A lending protocol assumes the price oracle is manipulation-resistant. It isn't.
- A vault assumes the token it holds follows standard ERC-20 behavior. It doesn't (fee-on-transfer, rebasing).
- A governance contract assumes one identity = one vote. But identities are transferable.
- A bridge assumes the L1 and L2 state are synchronized. They aren't, briefly.

The code is "perfect." The math checks out. The access control is tight. But somewhere, deep in the design, there's a **silent handshake between two contracts that was never formalized** — and the attacker finds the gap.

### The Takeaway

> Don't just audit the logic. Audit the assumptions.
>
> Every time Contract A relies on Contract B, ask:
> **"What is A assuming about B that B never explicitly promised?"**

In this case, one question would have caught it: *"Can a badge change hands?"* The answer was yes. The Guild never checked.
