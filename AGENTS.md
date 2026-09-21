# AGENTS.md

This file provides guidance to your coding agent when working with code in this repository.

# Communication Principles

Always chat as /caveman

However when writing artefacts, such as .md files or comments, be succinct but fluent.

# Development Principles

## Simplicity

In character, in manner, in style, in programming, in all things, the supreme excellence is
simplicity.

## Be in Contact with Reality

- Prefer executing against real data, running spikes, and testing/monitoring early over reasoning
  locally about what *would* happen.
- When you catch yourself theorising about behaviour you could instead observe, observe it — run the
  query, the spike, the smoke test.
- Bias the first contact towards cheap, reversible, read-only touches (queries, dry runs, spikes)
  before mutating anything real.
- Build a thin, working end-to-end slice before perfecting any single layer — a tracer bullet that
  proves the whole path connects, then iterate inside it. A flawless component wired to nothing has
  had no contact with reality.
- Never program by coincidence. Don't accept code that works without knowing *why* it works — luck
  is indistinguishable from correctness until it runs out. "It passes now" is not "it's correct"; if
  you can't explain why, you haven't observed enough yet.

## Resiliency

- On any deviation from the happy path, fail closed — raise immediately and block all forward
  progress. Treat that failure as the trigger to self-heal via bounded, idempotent retry under a
  supervisor. If retries are exhausted, dead-letter and escalate for human attention.
- Enforce invariants at the layer that can't be bypassed — a database constraint beats an
  application check, a real test beats a mock.

## Automation

- Flowing from resiliency, the broad goal with any of my programs is full automation, minimising for
  intervention.
- When intervention is required, as is inevitable for some program, it should be incredibly focused.

# Development Standards

- I think programmers are far too fast to over-abstract. I hate over-abstraction. Instead, let
  abstraction emerge as required to solve specific problems - be very clear about that.
- Well organised code is brilliant - structure keeps necessary complexity in as simple a form as
  possible.
- Similar to infrastructure-as-code, I like 'everything-as-code'. Having processes, even once-off
  processes, in scripts, make commands, etc enables auditability.

## Orthogonality

A change in one place must not ripple into another that has no reason to change with it. The root
cause is nearly always the same: **knowledge that should live in one owned place has leaked into the
modules that merely use it.** Hunt for that pattern.

- **One owner per concept.** A state machine, a config schema, a pricing rule, an external API —
  each has one home; callers ask it rather than re-encode it. If renaming a field forces edits
  across files that share no purpose, the concept has no owner.
- **Wrap every external axis of change behind an adapter.** One client per third-party API, storage
  layer, or database, with retry/error/serialisation trapped inside; business logic never builds the
  call inline. A vendor change should have one blast site.
- **Keep the dependency graph a tree, not a web.** Depend downward on shared foundations; never
  sideways between peers, never upward from foundation into the things that use it.
- **Separate the kinds of model.** API payloads, persistence rows, and domain objects are different
  axes — don't let one masquerade as another.
- **Inject dependencies at composition roots.** Build at startup/CLI entry and pass down. A
  dependency you can't see in the signature — a hidden global, a module-level singleton — couples
  invisibly.
- **Watch fan-in hubs.** A module with many callers couples even when imports are one-directional.
  Keep hubs narrow and pure.

## Testing Doctrine

- **Find bugs once.** Every escaped bug becomes a test that reproduces it, written before the fix.
- **Test the contract, not the implementation.** Assert on observable behaviour and public
  interfaces, so a refactor doesn't break the suite for no reason.
- **Fast and deterministic by default.** No reliance on wall-clock, network, or ordering. Flaky is
  worse than absent — quarantine or fix, never ignore.
- **Test at the seams that matter.** Business logic and the edges where things integrate, not
  trivial glue or generated code.
- **A failing test is a precise message.** Name it for the behaviour it pins; on failure it should
  say *what broke* without a debugger.
- **In contact with reality.** Favour real data and shapes over mocks that re-assert your own
  assumptions. One honest integration test beats ten mock-heavy ones that pass regardless of truth.

## Automated Programs

Aim for unattended operation:

- **Idempotent.** Re-running a unit converges to the same state — the precondition for blind retry.
- **Typed failures.** Permanent (dead-letter, never retry) versus transient (retry/redeliver), so
  the supervisor decides without a human.
- **Converge, don't trust events.** Pair every fast event path with a reconciliation loop that
  re-derives desired-vs-actual and closes the gap.
- **Own the schedule externally.** One-shot units; a supervisor (launchd/cron) owns cadence and
  single-instance — never an internal `while-sleep`.
- **Fail loud at setup, silent-proof at runtime.** Validate config/env while a human is present; the
  unattended tick must never silently no-op.
- **Guard the irreversible.** Blast-radius limits (prod guards, `--dry-run` previews) as tests and
  flags, not conventions.
- **Observable by default.** Structured, greppable logs/metrics plus a heartbeat — an unobserved
  automation is indistinguishable from a dead one.
- **Close the loop to action.** Alerts trigger automated triage, not just a human inbox.

## Python Development Standards

### Code Comments

Comments should be rare. Code should be self-documenting through effective naming conventions and
clean logic.

**Valid reasons for comments:**
- Justifying subtle, non-obvious or counterintuitive decisions
- Complex regex patterns (nearly impossible to read)
- Tricky algorithms with non-obvious time/space tradeoffs
- Workarounds for third-party library bugs
- Business rule constraints that aren't obvious from code

**Docstrings:** Acceptable as high-level summaries when purpose isn't clear. Prefer good typing over
explaining each input argument.

If you must add a comment, keep it very succinct. Provide only the content relevant to the reasons
above. For a comment to be more than 1 line, it must have an incredibly compelling reason in line
with those above. These are rarely justified.

### Type Annotations

- Type annotations are very important
- Prefer built-in types over `from typing ...`
- Use `|` and `None` instead of `Union`, `Optional`
- Avoid `Any` except under extreme circumstances

### Import Management

- Always import at the top of the script for base-python or installed packages
- NEVER use conditional imports with try/except to handle missing packages
- Don't deprecate code with import bypasses - if a function moves from script A to script B, update
  all references to import directly from script B instead of creating a passthrough import in script
  A

### Code Organization

- Use `_` prefix for internal attributes and methods in classes
- Don't write thin wrappers unless they save large amounts of code - call methods directly
- Favour methods and properties on a class over module-level functions — a module-level function is
  the last resort, for genuinely standalone behaviour that belongs to no owner. If a function takes
  an object as its main argument, it wants to be a method on it
- Remove deprecated code completely rather than creating compatibility layers

### File Paths

- I often use a `.cache` for local storage. When doing so, I will setup a `CACHE_DIR` or
  `get_cache_dir()`. Look for these in the `utils` or `path.py` and if they exist, use it, rather
  than manually defining it.
- It's important to use the var because you will often be working from worktrees and I want a
  centralised cache.

### Python Execution

- For stdlib-only python scripts, run python directly. Otherwise, use `uv run` for all Python script
  executions

## Updating files

Write and edit files with the direct file tools, never by shelling out to `cat >` or a heredoc —
safer, and already approved.

## Once-off Scripts

For once off scripts such as backfills or spikes, please date the top of the script for auditability
purposes.

## Naming

The first word that comes to mind is usually the most generic one available. Name by what a thing
means in the domain, not how it's built — `active_users`, not `filtered_list` — and borrow the words
a domain expert would use. The verb is a promise about cost and effect: `get_` is a cheap accessor,
`fetch_` does I/O, `compute_` is expensive. Cut noise words (`data`, `manager`, `helper`, `_obj`).
One operation, one verb — scattered synonyms imply distinctions that don't exist.

## Ubiquitous Language

Each repo's domain glossary is `.library/VOCAB.md` — read it; it is the source of truth for what
terms mean there. Flag conflicts and fuzz when you hit them rather than papering over.
