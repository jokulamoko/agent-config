---
name: vocab
description: Curate .library/VOCAB.md — the project's ubiquitous language.
---

# Vocab

Build and sharpen the project's **ubiquitous language** — the opinionated glossary of terms that carry project-specific meaning. One glossary per repo, at `.library/VOCAB.md`; the global `CLAUDE.md` already points every repo at it, so you only build the glossary — you never wire it up.

VOCAB.md is a glossary and nothing else. Not a spec, not a scratch pad, not a home for implementation decisions. General programming concepts — timeouts, retries, error types — never belong, however much the project leans on them; a term earns a place only if its meaning is specific to *this* domain.

## Describe, don't explain

An entry says **what a concept is** and **what it is responsible for** — at the level a domain expert would speak. It never explains **how the concept is built or how it behaves under the hood.** That is the one rule the file drifts away from, so hold it hard.

**The refactor test.** Would the sentence still be true after a refactor that changed the mechanism but kept the concept? If not, cut it. A definition survives any rewrite of the code; a mechanism description dies with the implementation it describes.

**Mechanism smells — cut on sight:**
- Columns, fields, nullability, table names (`crop_found: None = …`, "the `refused_until` column")
- Routes, endpoints, buttons, keyboard shortcuts, file paths, function signatures
- Algorithms and step orders ("re-walks from the top and writes only the missing images")
- Retry counts, strike counts, timeouts, exit codes, cache keys
- Historical rationale ("the two ever looked like one status because…"), migration notes, "why persisted"

The *distinction* that defines a term is not mechanism and stays — "a Refusal is a fact about the client, not the image" describes what the concept **is**. The *machinery* behind it goes. When in doubt, keep the sentence that a domain expert would say out loud and cut the one only an engineer reading the code would.

**Sub-labels are governed.** Only two are allowed:
- `_Avoid_:` — the losing synonyms, always.
- `_In code_:` — a bare pointer to where the concept lives (a class or model name), used sparingly and only when it genuinely helps locate it. One clause, not a paragraph.

Any other italic sub-label (`_Why_`, `_Why persisted_`, `_Derived_`, `_Note_`, …) is mechanism or rationale wearing a label — fold the real content into the definition or delete it.

## Steps

1. **Locate the glossary.** Read `.library/VOCAB.md`. If it exists, you're *sharpening*; if not, you're *seeding* — create it lazily once the first term resolves, not before.

2. **Gather the terms in play.**
   - *Sharpening:* take the term(s) or topic from `$ARGUMENTS`, or from what the current session has been circling.
   - *Seeding:* mine the domain — read `CLAUDE.md`, the rest of `.library/`, and the names the code leans on. Collect the terms a domain expert would reach for, not every noun.

3. **Sharpen each term before you write it** — don't transcribe, interrogate:
   - **Prune to the concept.** Run the refactor test over every existing sentence and cut what fails it. Sharpening is as much deletion as addition — most drifted entries need cutting, not extending.
   - **Challenge conflicts.** When a term clashes with an existing entry, force the choice: "VOCAB defines 'cancellation' as X, but you mean Y — which stands?"
   - **Sharpen fuzz.** When a word is vague or overloaded, pin the canonical concept and bury the rivals under `_Avoid_`. Be opinionated; that is the point.
   - **Stress-test with scenarios.** When the boundary between two concepts is fuzzy, invent edge cases that force precision about where one term ends and the next begins.
   - **Cross-reference the code.** Check the code agrees with the definition; surface contradictions.
   - **Reject the general.** If it isn't specific to this domain, it doesn't go in.

4. **Write entries inline as they resolve.** Use the format below. Capture each term the moment it's settled — don't batch them to the end.

## Format

```md
# {Project} Vocabulary

{One or two sentences: what this project is, so the terms have a frame.}

## {Optional cluster heading}

**Order**:
A customer's request to buy, once submitted and priced.
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent after delivery.
_Avoid_: Bill, payment request
```

- **Definitions stay tight** — one to three sentences, what it *is* and what it owns. If it runs longer, you're explaining mechanism; cut back.
- **Every synonym war ends in an `_Avoid_` line** — name the losers so they stop resurfacing.
- **Group under headings only when clusters emerge.** A flat list is fine when the terms cohere.
