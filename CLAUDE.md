# CLAUDE.md

This file provides guidance to your coding agent when working with code in this repository.

# Top Principles

## Simplicity

In character, in manner, in style, in programming, in all things, the supreme excellence is simplicity.

## Be in Contact with Reality

- Prefer executing against real data, running spikes, and testing/monitoring early over reasoning locally about what *would* happen. 
- When you catch yourself theorising about behaviour you could instead observe, observe it — run the query, the spike, the smoke test. 
- Bias the first contact towards cheap, reversible, read-only touches (queries, dry runs, spikes) before mutating anything real.
- Build a thin, working end-to-end slice before perfecting any single layer — a tracer bullet that proves the whole path connects, then iterate inside it. A flawless component wired to nothing has had no contact with reality.
- Never program by coincidence. Don't accept code that works without knowing *why* it works — luck is indistinguishable from correctness until it runs out. "It passes now" is not "it's correct"; if you can't explain why, you haven't observed enough yet.

## Resiliency

- On any deviation from the happy path, fail closed — raise immediately and block all forward progress. Treat that failure as the trigger to self-heal via bounded, idempotent retry under a supervisor. If retries are exhausted, dead-letter and escalate for human attention.
- Enforce invariants at the layer that can't be bypassed — a database constraint beats an application check, a real test beats a mock.

## Automation

- Flowing from resiliency, the broad goal with any of my programs is full automation, minimising for intervention.
- When intervention is required, as is inevitable for some program, it should be incredibly focused.

# General Development Standards

- I think programmers are far too fast to over-abstract. I hate over-abstraction. Instead, let abstraction emerge as required to solve specific problems - be very clear about that.
- Well organised code is brilliant - structure keeps necessary complexity in as simple a form as possible.
- Similar to infrastructure-as-code, I like 'everything-as-code'. Having processes, even once-off processes, in scripts, make commands, etc enables auditability.

## Orthogonality

Unrelated things should be independent. A change in one place must not ripple into another that has no reason to change with it. Eliminate effects between things that aren't conceptually related — that's what keeps a system cheap to change and safe to reason about in isolation.

The root cause of most non-orthogonality is the same: **knowledge that should live in one owned place has leaked into the modules that merely use it.** Hunt for that pattern.

- **One owner per concept.** A state machine, a config schema, a pricing rule, an external API — each should have a single home that owns it. Callers ask it; they don't re-encode it. If adding a state or renaming a field forces edits across several files that otherwise share no purpose, the concept has no owner.
- **Wrap every external axis of change behind an adapter.** Third-party APIs, storage, the database — one client/service each, with the retry/error/serialisation concerns trapped inside. Business logic never builds the call inline. A vendor change should have one blast site.
- **Keep the dependency graph a tree, not a web.** Depend downward on shared foundations; never sideways between peers, never upward from foundation into the things that use it. Cross-peer imports are a smell.
- **Separate the kinds of model.** API payloads, persistence rows, and domain objects are different axes — don't let one masquerade as another.
- **Inject dependencies at composition roots.** Build things at startup/CLI entry and pass them down. Hidden globals and module-level singletons couple invisibly — a dependency you can't see in the signature is one you'll trip over.
- **Watch fan-in hubs.** A module with many callers is a coupling point even when imports are one-directional. Keep hubs narrow and pure; resist letting them accrete responsibilities.

Orthogonality is the structural twin of simplicity: it's how you keep necessary complexity from spreading.

## Testing Doctrine

- **Find bugs once.** Every bug that escaped becomes a test that reproduces it before the fix. A class of bug should never be free to recur silently.
- **Test the contract, not the implementation.** Assert on observable behaviour and public interfaces so refactors don't break the suite for no reason — this is orthogonality applied to tests.
- **Fast and deterministic by default.** No reliance on wall-clock, network, or ordering. Flaky is worse than absent; quarantine or fix, never ignore.
- **Test at the seams that matter.** Concentrate effort on business logic and the edges where things integrate — not on trivial glue or generated code.
- **A failing test is a precise message.** Name it for the behaviour it pins; on failure it should tell you *what broke* without a debugger.
- **In contact with reality.** Favour tests that run against real data/shapes over mocks that merely re-assert your assumptions. Prefer one honest integration test to ten mock-heavy ones that pass regardless of truth.

## Automated Programs

Programs should aim for unattended operation. The principles that make that safe:

- **Idempotent.** Re-running a unit must be safe and converge to the same state — the precondition for blind retry.
- **Typed failures.** Distinguish permanent (dead-letter, never retry) from transient (retry/redeliver) so the supervisor can decide without a human.
- **Converge, don't trust events.** Pair every fast event path with a reconciliation loop that re-derives desired-vs-actual and closes the gap.
- **Own the schedule externally.** Write one-shot units; let a supervisor (launchd/cron) handle cadence and single-instance — never an internal `while-sleep`.
- **Fail loud at setup, silent-proof at runtime.** Validate config/env at the human-present moment; the unattended tick must never silently no-op.
- **Guard the irreversible.** Encode blast-radius limits (prod guards, `--dry-run` previews) as tests/flags, not conventions.
- **Observable by default.** Emit structured, greppable logs/metrics and a heartbeat — an unobserved automation is indistinguishable from a dead one.
- **Close the loop to action.** Alerts should trigger automated triage, not just a human inbox.

## Python Development Standards

### Code Comments

Comments should be rare. Code should be self-documenting through effective naming conventions and clean logic.

**Valid reasons for comments:**
- Justifying subtle, non-obvious or counterintuitive decisions
- Complex regex patterns (nearly impossible to read)
- Tricky algorithms with non-obvious time/space tradeoffs
- Workarounds for third-party library bugs
- Business rule constraints that aren't obvious from code

**Docstrings:** Acceptable as high-level summaries when purpose isn't clear. Prefer good typing over explaining each input argument.

If you must add a comment, keep it very succinct. Provide only the content relevant to the reasons above.
For a comment to be more than 1 line, it must have an incredibly compelling reason in line with those above. These are rarely justified.

### Type Annotations

- Type annotations are very important
- Prefer built-in types over `from typing ...`
- Use `|` and `None` instead of `Union`, `Optional`
- Avoid `Any` except under extreme circumstances

### Import Management

- Always import at the top of the script for base-python or installed packages
- NEVER use conditional imports with try/except to handle missing packages
- Don't deprecate code with import bypasses - if a function moves from script A to script B, update all references to import directly from script B instead of creating a passthrough import in script A

### Code Organization

- Use `_` prefix for internal attributes and methods in classes
- Don't write thin wrappers unless they save large amounts of code - call methods directly
- When a function primarily relates to a particular class, make it a method or property of that class instead of a standalone function
- Remove deprecated code completely rather than creating compatibility layers

### File Paths

- I often use a `.cache` for local storage. When doing so, I will setup a `CACHE_DIR` or `get_cache_dir()`. Look for these in the `utils` or `path.py` and if they exist, use it, rather than manually defining it.
- It's important to use the var because you will often be working from worktrees and I want a centralised cache.

### Python Execution

- For stdlib-only python scripts, run python directly. Otherwise, use `uv run` for all Python script executions

## Updating files

I think its part of your learning to update big files using a pattern like this:

Bash(cat > {location} << 'PYEOF'
{python_script})

Don't do this - instead use your direct read/write commands. This is safer, more stable and already-approved.

## Once-off Scripts

For once off scripts such as backfills or spikes, please date the top of the script for auditability purposes.

## Naming

Think twice before committing to a name. The first word that comes to mind is
usually the most generic one available — pause and ask what this thing actually
*is* and *does* before you type it.

- **Reveal intent, not mechanism.** Name by what it means in the problem domain,
  not how it's implemented: `active_users`, not `filtered_list`.
- **Borrow the domain's vocabulary.** Use the words a domain expert would use
  (`ledger`, `invoice`, `quorum`). Don't invent programmer-ese for concepts that
  already have a real name.
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

When the name you want is already taken, check whether the incumbent is broader
than it should be. Often the existing thing is really a *specific* case wearing a
*general* name. Rename it more narrowly (`Cache` → `MemoryCache`, `Handler` →
`RetryHandler`) to free up the general term for the concept that truly deserves
it. Naming is a whole-namespace activity, not a local one — it's fine to edit
neighbors to make semantic room for a new term.

## Ubiquitous Language

Each repo keeps its **ubiquitous language** — the opinionated domain glossary —
in `.library/VOCAB.md`. Read it; it is the source of truth for what terms mean in
that project. Curating it is a deliberate act (`/vocab`); *noticing* when it needs
curating is a continuous one:

- **Flag conflicts.** When a term is used against its `VOCAB.md` definition, stop
  and name it: "VOCAB defines 'X' as A, but you seem to mean B — which stands?"
- **Flag fuzz.** When a word is vague or overloaded, ask which concept is meant
  before building on it: "'account' — the Customer or the User? Those differ."

Surface the tension rather than papering over it; when the resolution is worth
recording, reach for `/vocab` so the glossary absorbs it instead of drifting.

# Conversations

## Your biggest flaw

The biggest flaw of most LLMs is unnecessary verbosity. As much as possible, give direct answers to direct questions.
If the user wants, they will ask for more detail - let that detail "unfold" naturally.

## Ordered lists over unordered

When you give me lists of ideas or questions, number them (1, 2, 3 or a, b, c). 
Try not to re-use the same index for a single response.
Never give me unordered `-` bullets. 
All of this makes it easy for me to respond to each item quickly and unambiguously.

## Challenges

I love to have my ideas challenged. If I'm asking you to do something, assume it comes
with the tag:
`If this instruction is problematic, let me know. Explain why and we will discuss`.
I may still reject your challenge and ask you to follow my original instruction anyways,
in which case please execute. But no harm in a debate.
