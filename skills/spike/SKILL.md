---
name: spike
description: Time-boxed, throwaway exploration to answer one specific question — is this approach viable, where does this bug live, how does this library behave. Optimise for learning speed, not code quality; the code is disposable. Use when the user wants to investigate, prototype, or de-risk before committing to real implementation ("spike on X", "can we even do Y", "throwaway prototype to check Z").
disable-model-invocation: false
---

# Spike

A spike answers **one question** with code you're allowed to throw away. Its only
product is *knowledge* — "yes this works", "no, because of X", "the bottleneck is Y".
The code is scaffolding to reach that answer, not an artefact to keep.

The failure mode is a spike that quietly becomes production: half-baked exploratory
code, written without care because it was "just a spike", ends up shipped. Keep the
wall between spike and real work explicit.

## How to run it

1. **State the one question.** Write it down in a sentence before touching code:
   *"Can we stream Parquet from R2 without buffering the whole file?"* If you have two
   questions, that's two spikes — or you've not found the real one yet. A spike with a
   fuzzy question runs forever.

2. **Set the box.** Decide up front what "done" looks like and roughly how far you'll
   go before you stop and report — a working proof, a definitive blocker, or "enough to
   recommend". When you hit it, stop; don't gold-plate a throwaway.

3. **Optimise for learning speed.** Hardcode, stub, skip error handling, skip tests,
   use the dirtiest path to the answer. This is the *one* context where messy code is
   correct — the point is the finding, fast.

4. **Keep it visibly disposable.** Put spike code somewhere clearly marked — a
   `.spikes/` dir (or `.cache/` if that's the local convention) — never inline in the
   real source tree where it can be mistaken for production. Per the once-off-scripts
   rule, **date the top of the script** so it's auditable later.

5. **Report the finding, then decide the code's fate.** Lead with the answer to the
   question, the evidence, and a recommendation. Then explicitly choose one:
   - **Throw it away** — default. Delete it; the knowledge is the keeper.
   - **Keep as reference** — leave it dated in `.spikes/`, clearly not production.
   - **Promote** — rewrite it properly as real work (don't graduate spike code as-is;
     re-implement with tests, types, and care).

Never let step 5 default to "leave the spike code wired into the app". Decide on
purpose.
