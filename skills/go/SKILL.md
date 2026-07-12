---
name: go
description: The user is going away from keyboard and wants work pushed as far as it can go without them. Use when the user says they're going AFK, stepping out, or "take this as far as you can while I'm gone".
disable-model-invocation: false
---

# AFK

The user is stepping away. Your job is to make the most of their absence: drive the
work as far as it can go on its own, and don't sit idle waiting on them.

## The core rule

**Anything that genuinely needs the user's input is "blocked".** A decision only they
can make, a credential only they have, an ambiguity with no defensible default, an
outward-facing or hard-to-reverse action that needs their sign-off — these stop *that
thread*, not the session.

But the bar for "blocked" is high. Before parking anything:

1. **Exhaust the defensible defaults.** If there's a reasonable, reversible choice you
   can make and note for them, make it and keep going. Don't block on something you can
   decide and they can veto later.
2. **Read the code, not their mind.** Most "questions" are answerable by looking
   harder — existing patterns, conventions, tests, git history. Investigate before you
   declare yourself stuck.
3. **Separate the blocker from the work around it.** One blocked sub-task rarely blocks
   the whole task. Carve off what you *can* do and do it.

## How to work while they're gone

1. **Push the main task to its real boundary.** Implement, test, and verify everything
   that doesn't cross a genuine blocker. Get it to the furthest defensible state.
2. **When you hit a true blocker, park it — don't stop.** Record what's blocked and the
   specific input you need, then move to the next thing.
3. **Then work the periphery.** Useful work adjacent to the main task that doesn't need
   them: tests, docs, cleanup, refactors you'd flagged, reproducing a reported issue,
   investigating the blocked questions so you can present options rather than open
   questions, tightening error handling, removing dead code. Prefer work that helps the
   main task land once they're back.
4. **Stay reversible at the edges.** While unsupervised, don't do the things that
   normally want explicit approval — pushing, opening PRs, deploying, sending anything
   outward, deleting things you didn't create. Stage them and leave them for their
   return unless they've already told you to proceed.

## When they get back

Give them a tight report, optimised for fast unblocking:

1. **Done & verified** — what you completed, and how you know it works.
2. **Blocked — needs you** — a numbered list. For each: what's blocked, the exact
   decision/input required, and the options you've already worked up (with a
   recommendation). Make each one answerable in a sentence.
3. **Peripheral work done** — what else you progressed in the meantime.
4. **Staged, awaiting your go** — anything reversible-at-the-edges you held back
   (pushes, PRs, sends) pending their approval.

Lead with the blockers if there are any — that's what they need to act on first.
