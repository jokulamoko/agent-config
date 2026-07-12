---
name: vocab
description: Curate .library/VOCAB.md — the project's ubiquitous language.
---

# Vocab

Build and sharpen the project's **ubiquitous language** — the opinionated glossary of terms that carry project-specific meaning. One glossary per repo, at `.library/VOCAB.md`; the global `CLAUDE.md` already points every repo at it, so you only build the glossary — you never wire it up.

VOCAB.md is a glossary and nothing else. Not a spec, not a scratch pad, not a home for implementation decisions. Define what a term *is*, not what it *does*. General programming concepts — timeouts, retries, error types — never belong, however much the project leans on them; a term earns a place only if its meaning is specific to *this* domain.

A VOCAB entry defines what a concept is and what it is responsible for — never how it is built. If a sentence names a column, route, endpoint, button, or file, it belongs in a docstring, not the glossary.

## Steps

1. **Locate the glossary.** Read `.library/VOCAB.md`. If it exists, you're *sharpening*; if not, you're *seeding* — create it lazily once the first term resolves (step 4), not before.

2. **Gather the terms in play.**
   - *Sharpening:* take the term(s) or topic from `$ARGUMENTS`, or from what the current session has been circling.
   - *Seeding:* mine the ubiquitous language from the domain — read `CLAUDE.md`, the rest of `.library/`, and the names the code leans on. Collect the terms a domain expert would reach for, not every noun.

3. **Sharpen each term before you write it** — don't transcribe, interrogate. The moves:
   - **Challenge conflicts.** When a term clashes with an existing entry, force the choice: "VOCAB defines 'cancellation' as X, but you mean Y — which stands?"
   - **Sharpen fuzz.** When a word is vague or overloaded, pin the canonical concept and bury the rivals under `_Avoid_`: "'account' — the Customer or the User?" Be opinionated; that is the point.
   - **Stress-test with scenarios.** When the boundary between two concepts is fuzzy, invent concrete edge-case scenarios that force precision about where one term ends and the next begins.
   - **Cross-reference the code.** Check the code agrees with the definition; surface contradictions: "the code cancels whole Orders, but you said partial — which is right?"
   - **Reject the general.** If it isn't specific to this domain, it doesn't go in.

4. **Write entries inline as they resolve.** Use the format below. Capture each term the moment it's settled — don't batch them to the end.

Apply the **refactor test** to an edits: Ask whether the sentence would survive a refactor that preserved the concept. If not, delete it.

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

- **Definitions stay tight** — one or two sentences, what it *is*.
- **Every synonym war ends in an `_Avoid_` line** — name the losers so they stop resurfacing.
- **Group under headings only when clusters emerge.** A flat list is fine when the terms cohere.
