---
name: tdd
description: Pin what "correct" means in tests before any implementation — an isolated test-writer lands example tests for exact values and boundaries plus property tests (Hypothesis) for invariants, and a gate script proves them red (new behaviour) or green (refactor) before a line of implementation is written. Use before implementing any bug fix, feature or refactor.
---

# TDD

Write the tests that define done, before the code that satisfies them. `$ARGUMENTS` is the
behaviour to pin; absent that, take it from the investigation just finished.

Tests written after the code test what the code *does*. Only tests written before it test what
it *should* do — and a context already holding the intended implementation drifts toward it, so
they get written somewhere else, by an agent handed the contract and not your plan.

Doctrine — contract over implementation, real data over mocks, find bugs once — lives in the
root `CLAUDE.md`. This skill is the process; `tdd-gate.py` beside it is the part that does not
depend on you remembering it.

## 1 — State the oracle

Two modes. Pick before writing anything:

- **`red`** — the behaviour does not exist or is wrong. Features and bug fixes. The tests must
  fail now and pass after.
- **`pin`** — the behaviour exists and must survive a change. Refactors. The tests characterise
  today's behaviour, and must be green before *and* after.

Then write down what the tests must hold. Five kinds:

- **Known answers.** Concrete input → exact expected output. Not "returns a list" — the list.
- **Boundaries.** Empty, zero, one, max, duplicate, out-of-order, missing, unicode, timezone.
- **Invariants.** What holds for *every* valid input: round-trip, idempotence, conservation,
  ordering, monotonicity, agreement with a slow reference implementation, never-raises.
- **Agreements.** For each pair of components that must name the same set, key or format —
  producer and consumer, writer and reader, fitter and scorer — one claim computed from both
  sides rather than restated on each. When these break neither side is individually wrong, which
  is why they break silently and stay broken.
- **Failure modes.** What must raise, and exactly what it raises.

Every item needs a name and a stated expected result. Then re-grade the list twice:

1. **Would it still be true at another size, count or ordering?** Then it is an invariant wearing
   a known answer's clothes. Make it a property test, and keep the original number as one
   `@example`.
2. **If it were false, what would I see?** Sort the oracle by that — silent and permanent at the
   top, loud exception at the bottom. That order is the budget: the surface is always larger than
   the effort worth spending on it, and a claim whose falsity raises is already half tested by
   the runtime.

You need a stateable *expected result*, not a diagnosed cause: a bug you can reproduce but not
yet explain is fully oracle-able, since the reproduction pins the symptom and the cause is what
step 6 is for. If you cannot say what the right answer *is*, stop — guessing encodes the wrong
contract with more conviction than a plan ever could.

For a bug fix, one oracle item is mandatory: the exact input that triggers the bug today, with
the answer it should have given.

## 2 — Spawn the test-writer

One `general-purpose` agent via the Agent tool — it must run the suite, so not `Explore`.
Isolation is the point: it keeps the implementation shape out of the tests, and the runner noise
out of your context.

Give it:

- **The oracle** from step 1, verbatim and in its order, and the mode. Say that the order is
  where to spend effort.
- **The seams.** The public functions, classes or endpoints the tests should call — signatures,
  not bodies.
- **The conventions.** Where tests live, the exact runner command, the fixtures available, and
  one sibling test file to imitate.
- **The mandate.** Tests only; it writes no implementation. In `red` mode a symbol may not exist
  yet, so a bare signature stub raising `NotImplementedError` is expected — `tdd-gate.py stub on`
  opens the guard hook for it, `stub off` closes it, and the red gate refuses while it is open.
- **Property tests are not optional.** Hypothesis in Python, the language's equivalent
  elsewhere. Add the dependency if the project has none. Example-only is a decision to state out
  loud with a reason, not a default to drift into.
- **The return.** The test file paths, and the verbatim output of its run.

Give it **nothing** about how you intend to implement — no plan, no diff, no "it'll probably
live in X". It gets the contract; the shape of the solution is yours alone.

## 3 — Prove the gate

```
~/.claude/skills/tdd/tdd-gate.py red <test-path>...    # new behaviour
~/.claude/skills/tdd/tdd-gate.py pin <test-path>...    # refactor
```

Exit 0 or the step is not done. Four ways to fail, each a finding rather than an obstacle — the
script prints the reasoning, so act on what it says instead of working around it. **BROKEN**:
errored before reaching an assertion, and not-passing is not red. **NOT RED**: already passes, so
either the bug is unreproduced or the assertion is tautological. **NOT GREEN**: a `pin` test that
mis-describes today's behaviour, or a real bug that needs its own `red` cycle first. **SKIPPED**:
pins nothing.

On success it records the proven node IDs under the worktree's git directory. That opens the
guard hook, and there is nothing to commit and nothing to ignore — the anchor commit is the
durable artefact.

## 4 — Judge the tests

Read them against the original request. You wrote the oracle, so you are the last person who can
tell whether it encodes what was actually asked — and unlike a plan, these tests are concrete
enough to judge exactly. Reject and rewrite:

- Assertions on the internals of the thing under test — private methods, its own call counts,
  mock `assert_called_with`. Call counts *at the boundary* are the exception and are wanted:
  "`--dry-run` fetches nothing", "a cached load opens no socket". Cost is a contract.
- Mocks standing in for the thing under test, rather than for the boundary beyond it.
- Kitchen-sink tests bundling unrelated behaviours; a failing test should be a precise message.
- Properties too weak to fail: `assert result is not None`, `assert len(x) >= 0`.
- Restatements of a constant. Re-typing a literal table asserts only that copy-paste worked. One
  change-detector is fair when a silent edit would be dangerous — say so in the docstring. A
  second is just a second copy. Assert the table's properties instead.

Then re-run step 3: edited tests are unproven tests.

## 5 — Commit

Commit the tests on their own, before any implementation. That commit is the anchor: everything
after it is the change, and anyone can check it out and watch the gate go red.

## 6 — To green

```
~/.claude/skills/tdd/tdd-gate.py green
```

Implement, then run it. It re-runs the pinned node IDs and requires every one to pass, so
deleting or renaming a test on the way to green fails as **VANISHED** rather than passing
quietly.

**Do not edit the tests to fit the implementation.** A test can be genuinely wrong; when it is,
say so in the chat with the reason and change it deliberately. Silent test edits are how TDD
becomes theatre.

The fastest route to green is a hardcoded return; the property tests exist so that route closes.
Don't stop at first green — stop when the properties hold.

## 7 — A bug found later re-enters at step 1

Every bug found after the anchor — by running the thing, by a reviewer, by noticing a command
never returned — is its own `red` cycle:

```
~/.claude/skills/tdd/tdd-gate.py red --add <test-path>
```

`--add` unions into the branch's existing pins rather than replacing them. Write the oracle item,
prove it fails on today's code, then fix it. This is the step that gets skipped, because
implementation is writable by now and the fix looks obvious — and a fix committed without a test
that reproduced the bug first is the exact failure this skill exists to prevent.

When a property test found it, paste the shrunk counterexample into the test as `@example(...)`
and commit that with the fix. Hypothesis's `.hypothesis/examples` database will not do this for
you: it deletes entries once they stop failing, so committing it pins nothing.

## Boundaries

- One test-writer, not a swarm. Spawn a second only when the work spans genuinely independent
  seams.
- Visual and UI work has no stateable assertion to pin — verify it in a browser instead. Every
  other kind of change has a mode here.
- The test-writer is read-only on implementation code, not on the repo — it lands test files and
  runs them. All implementation is yours, in step 6.
- Cost and latency are caught here only where a boundary call count pins them. The rest — did it
  actually run, against real data, end to end — is `/contact`'s job, after implementation.
- `TDD_RUNNER` overrides the runner the gate invokes; it defaults to `uv run pytest` when a
  `uv.lock` is present, otherwise `pytest`.
- The guard hook gates `feat/` and `fix/` branches holding no implementation yet — a branch
  already carrying it, committed or modified, is work in flight and passes freely, so adopting
  this skill never strands a leaf already underway. It guards `Write`/`Edit`, not shell
  redirection: a guardrail against drifting past the step, not a boundary against a bypass.
