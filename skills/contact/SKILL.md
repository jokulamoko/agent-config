---
name: contact
description: Audit how much "contact with reality" a feature or change has actually had versus what's still purely theoretical, then name the single cheapest next touch that would de-risk it most. Use to sanity-check before trusting work that's been developed mostly by local reasoning ("has this had contact with reality", "/contact", "are we sure this works").
disable-model-invocation: false
---

# Contact

The philosophy: *be in contact with reality*. Code that has only ever existed in
your head, your editor, or an argument is unproven, no matter how clean it is or how
finished it reads — confidence built entirely from local reasoning. This skill stops
and audits how much the work has actually touched reality, then names the cheapest
next touch. The output is not reassurance; it's the one command worth running next.

## How to run it

Produce a short ledger for the feature or change under scrutiny (use `$ARGUMENTS`
to target a specific feature; otherwise take the work in focus). Keep it concrete —
name the actual queries, runs, and observations, not vibes.

1. **What contact has this had?** Enumerate the *concrete* touches that have already
   happened. Be specific and honest — a touch only counts if it actually occurred:
   - Run against real or production-shaped data (not toy fixtures)?
   - Executed end-to-end, not just unit-tested in isolation?
   - Observed in logs, metrics, or traces while running?
   - Exercised by a test backed by realistic inputs?
   - Seen or used by a real user?

2. **What's still purely theoretical?** Name the parts that exist only in code or
   argument and have never met reality. Be precise about *which* behaviours are
   assumed rather than observed — the edge case you reasoned through but never ran,
   the integration you're "pretty sure" works, the query you wrote but never executed.

3. **Next contacts, cheapest first.** List a few concrete ways to close the biggest
   gaps, ordered by cost with the cheapest at the top — a query, a `curl`, a
   print-and-run, a one-off spike, a staging smoke test, an end-to-end run. For each,
   say in a few words what it costs and what gap it closes, so the trade-off between
   cheaper-but-shallower and pricier-but-deeper is visible. This is the payload. The
   top item is the one to reach for first.

## Boundaries

- **Cheap and reversible first.** Bias the recommended next touch towards read-only,
  reversible contact (queries, dry runs, spikes, staging) before anything that
  mutates real state. This skill is not licence to YOLO against production — closing
  a contact gap by breaking something real is a bad trade.
- **Honest accounting only.** "There's a unit test" is weak contact if the fixtures
  are invented; say so. The value is in an unflinching ledger, not a flattering one.
- **End in a touch, not a vibe.** If the audit doesn't produce concrete next
  actions, it failed. The deliverable is the ranked list of touches worth running;
  offer to run the cheapest one right now.
- If the work has genuinely had thorough contact already, say so plainly and stop —
  don't manufacture doubt.
