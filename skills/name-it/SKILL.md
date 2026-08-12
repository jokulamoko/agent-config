---
name: name-it
description: Deliberate naming session for a thing whose name matters — a module, a domain concept, a public API, a term that keeps causing confusion. Use when a name is contested, when the obvious word is taken, or when the user asks what to call something ("what should I name this", "/name-it", "this name feels wrong").
---

# Name It

The first word that comes to mind is usually the most generic one available.
Ask what the thing actually *is* and *does* before typing.

## The rules

- **Reveal intent, not mechanism.** Name by what it means in the problem domain,
  not how it's implemented: `active_users`, not `filtered_list`.
- **Borrow the domain's vocabulary.** Use the words a domain expert would use
  (`ledger`, `invoice`, `quorum`). Don't invent programmer-ese for concepts that
  already have a real name. Check `.library/VOCAB.md` first — if the concept has
  an entry, that name wins.
- **Match the verb to the work.** `get_`/`is_` are cheap accessors. Use
  `fetch_`/`load_` for I/O, `compute_`/`build_` for expensive or constructive
  work, `parse_`/`render_`/`derive_` when that's literally what happens. The verb
  is a promise about cost and effect — keep it.
- **One concept, one word.** Pick `fetch` *or* `retrieve` *or* `get` for a given
  operation and use it everywhere. Scattered synonyms imply distinctions that
  don't exist.
- **Cut noise words.** `data`, `info`, `manager`, `helper`, `util`, `process`,
  `handle`, `_obj` add length without meaning. `Product` beats `ProductData`;
  `accounts` beats `account_list`.
- **Booleans read as assertions.** `is_active`, `has_pending`, `should_retry`,
  `can_edit` — and stay positive (`is_valid`, never `is_not_invalid`).
- **Scope sets length.** A loop index can be `i`; a module-level public function
  cannot. The more widely a name is visible, the more it must stand on its own.
- **Don't encode the type.** Type hints do that. Name the role: `users`, not
  `user_list`; `timeout`, not `timeout_int`.
- **Use consistent opposites.** `open/close`, `start/stop`, `source/dest`,
  `min/max`. Don't pair `begin` with `finish`.

A good name makes a comment unnecessary — if you reach for a clarifying comment,
try folding it into the name instead.

## When the name is taken

Check whether the incumbent is broader than it should be. Often the existing
thing is really a *specific* case wearing a *general* name. Rename it more
narrowly (`Cache` → `MemoryCache`, `Handler` → `RetryHandler`) to free up the
general term for the concept that truly deserves it.

Naming is a whole-namespace activity, not a local one — it's fine to edit
neighbours to make semantic room for a new term.

## Steps

1. **Say what the thing is** in one sentence, in domain language, without using
   the candidate name. If that sentence is hard to write, the concept is unclear
   and no name will save it.
2. **Check the namespace.** Grep for the candidate and its near-synonyms. Find
   out whether the word is taken, and by what — an incumbent wearing too general
   a name is a rename candidate, not a blocker.
3. **Offer 2–4 candidates**, each with the rule it satisfies and what it gives
   up. Numbered, so the user can pick by index.
4. **Recommend one** and say why. Don't present a tie.
5. **Apply it everywhere** once chosen — the name, its opposites, its
   derivatives, docstrings, and tests. A half-applied rename is worse than the
   original.
6. **Record it** in `.library/VOCAB.md` via `/vocab` if the term is
   domain-specific and contested. Most names don't meet that bar.
