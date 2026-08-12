---
name: vocab
description: Curate .library/VOCAB.md — the project's ubiquitous language.
---

# Vocab

Build and sharpen the project's **ubiquitous language** — the small, opinionated set of terms that carry project-specific meaning. One glossary per repo, at `.library/VOCAB.md`; the global `CLAUDE.md` already points every repo at it, so you only build the glossary — you never wire it up.

VOCAB.md is a glossary and nothing else. Not a spec, not a scratch pad, not a home for implementation decisions.

## The bar

**Adding a term is the exception.** A healthy glossary is short and grows slowly — a few dozen terms, most of them settled early. The usual outcome of running this skill is sharpening or deleting an existing entry, not appending a new one. If a session produces several new terms, you have almost certainly mistaken vocabulary for documentation.

Three tests, all of which a term must pass:

**1. Domain-specific.** General programming concepts — timeouts, retries, error types, caches — never belong, however much the project leans on them. The term must mean something *here* that it doesn't mean everywhere.

**2. Core, not derived.** Define the concept; do not define the things that flow from it. Once `Ledger` is defined, `ledger entry`, `ledger balance` and `ledger sync` all read correctly on their own — they are the core term plus ordinary English, and in context they need no help. Adding them buries the one definition that mattered under three that didn't.

Ask: *once the core term is defined, does this one still need explaining?* Usually no. Then leave it out.

**3. Contested.** A term earns a place when getting it wrong costs something — people use it two ways, rival synonyms compete for it, or a neighbouring concept keeps bleeding into it. A word everyone already uses identically needs no entry, however central it is.

When a term fails the bar but the confusion is real, the fix usually belongs in the *existing* entry — a sharper boundary, or an `_Avoid_` line — not in a new one.

## Describe, don't explain

An entry says **what a concept is** and **what it is responsible for**, at the level a domain expert would speak. It never explains **how the concept is built or behaves under the hood.** That is the one rule the file drifts away from, so hold it hard.

**The refactor test.** Would the sentence still be true after a refactor that changed the mechanism but kept the concept? If not, cut it.

**Mechanism smells — cut on sight:** columns, fields, nullability, table names; routes, endpoints, buttons, file paths, function signatures; algorithms and step orders; retry counts, timeouts, exit codes; historical rationale and migration notes.

The *distinction* that defines a term stays — "a Refusal is a fact about the client, not the image" describes what the concept **is**. The *machinery* behind it goes. When in doubt, keep the sentence a domain expert would say out loud and cut the one only an engineer reading the code would.

**Sub-labels are governed.** Only two are allowed:
- `_Avoid_:` — the losing synonyms, always.
- `_In code_:` — a bare pointer to where the concept lives, used sparingly. One clause, not a paragraph.

Any other italic sub-label (`_Why_`, `_Derived_`, `_Note_`, …) is mechanism or rationale wearing a label — fold the real content into the definition or delete it.

## Steps

1. **Locate the glossary.** Read `.library/VOCAB.md`. If it exists, you're *sharpening*; if not, you're *seeding* — create it lazily once the first term resolves, not before.

2. **Gather the candidates.** Take the term(s) from `$ARGUMENTS`, or from what the session has been circling. When seeding, mine the domain — `CLAUDE.md`, the rest of `.library/`, the names the code leans on — and collect only the terms a domain expert would reach for.

3. **Apply the bar.** Most candidates die here. Say which ones you rejected and why; a rejection is a real result, not a failure to deliver.

4. **Sharpen what survives** — don't transcribe, interrogate:
   - **Prune first.** Run the refactor test over the existing entry and cut what fails it. Sharpening is mostly deletion.
   - **Challenge conflicts.** When a term clashes with an existing entry, force the choice: "VOCAB defines 'cancellation' as X, but you mean Y — which stands?"
   - **Sharpen fuzz.** Pin the canonical concept; bury the rivals under `_Avoid_`. Be opinionated; that is the point.
   - **Stress-test boundaries.** Invent edge cases that force precision about where one term ends and the next begins.
   - **Cross-reference the code.** Check it agrees with the definition; surface contradictions.

5. **Write entries inline as they resolve** — don't batch them to the end.

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
