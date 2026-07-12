---
name: challenge-me
description: Pit your solution against an impartial sub-agent's independent take on the same problem, then get a recommendation that may blend the two.
disable-model-invocation: true
---

# Challenge Me

I've brought you a problem *and* my own high-level solution. Don't grade my solution — that just anchors you to it. Instead, get a **blind challenger**: a fresh sub-agent that sees only the problem, never my answer, and works up its own solution from scratch. Two independent minds on the same problem, then a recommendation that takes the best of both.

The whole value rests on the challenger being **impartial** — it must never see my proposed solution. If it does, it stops being a second mind and becomes an echo. Guard that seam.

## Steps

1. **Understand the problem — not my solution.** Ask clarifying questions until you could hand the *problem* to someone who's never heard my take and they'd understand it fully. Investigate the codebase where that answers a question faster than I can. Ask one question at a time; a batch is bewildering. Completion criterion: you can write a problem brief that stands on its own, with zero trace of how I proposed to solve it.

2. **Spawn the blind challenger.** Launch one sub-agent (`general-purpose`, or `Plan` if the solution is an implementation strategy) seeded with the problem brief from step 1 **and nothing about my solution**. Its mandate: understand the problem, then produce its own high-level solution with the reasoning behind it. Prime it against the principles in the root AGENTS.md (simplicity, resiliency, orthogonality). Do not leak my approach, my framing of the trade-offs, or hints at the answer I'm leaning toward — any of these re-infect it. It returns its solution to you, not to me.

3. **Lay both solutions side by side and recommend.** Now surface my solution and the challenger's as genuine peers. Follow the **osusumewa** skill (`~/.claude/skills/osusumewa/SKILL.md`): name the axis they differ on, give each an impartial hearing, then close with an explicit おすすめ. The recommendation is free to be a **blend** — my structure with their error handling, their approach guarded by my constraint — when the synthesis genuinely beats either alone. Say why, and name what would flip it.

## Boundaries

- If clarifying reveals the problem is trivial, say so and skip the challenger — a second mind is for problems where mine might be wrong.
- One challenger, not a swarm. Spawn a second only if the problem spans genuinely independent areas one agent can't hold at once.
- The recommendation is an argument, not a verdict. If I push back, defend it or fold on the merits.
