---
name: leaf
description: Create an isolated worktree branch with its own database branch, investigate thoroughly, implement changes, document in .library/forks/, and push — cut from any named base branch, defaulting to local main, or off the current worktree when run from inside one. Use when starting a bug fix, feature, or refactor that needs isolation, including slicing a /decompose unit off a larger feature worktree.
---

# Leaf

Create an isolated worktree to work on a task. `$ARGUMENTS` describes the task.

**The base.** Every leaf has a *base* — the branch it is cut from and will eventually
merge back into. Determine it in this order:

- **Named in `$ARGUMENTS`** → that branch is the base, whatever it is. Take it when the task
  says so explicitly (`--base release/2.0`, "off `release/2.0`", "against `staging`"). It must
  be a local branch; if it only exists on the remote, create the local tracking branch first
  rather than basing on `origin/...`.
- **Otherwise, in the main repo** → the base is local `main`. The default case.
- **Otherwise, inside an existing worktree** → the base is *that worktree's branch*. The new
  leaf is a **sub-worktree**: cut from the parent's current HEAD and merged back into the
  parent (not main) when it lands. This is how you slice a `/decompose` unit off a larger
  feature worktree without disturbing it, and how sub-slices stack up before the parent
  itself lands on main.

Throughout the steps below, "the base" means this branch — where the old single-level
flow said "main", read "the base".

## Grill

I may request `/grill-me` specifically up front to interrogate the task — surfacing
hidden assumptions, missing scope, and the edge cases that the bare description glosses
over. But it shouldn't be always triggered; only run it when I ask for it.

## Setup

1. Derive a `<task-slug>` from the task description, using a `feat/`, `fix/`, or `chore/` prefix depending on the nature of the task.
2. Create the worktree with `leaf-setup.sh`, which sits beside this skill. Run it from
   anywhere in the repo:

   ```
   ~/.claude/skills/leaf/leaf-setup.sh <prefix>/<task-slug> [base]
   ```

   Pass the base only when the task named one; omit it otherwise. Without it the script infers
   the base from where you are — local `main` in the main repo, the current branch's `HEAD`
   inside a worktree. It records the base on the branch (`branch.<branch>.leafBase`) so later
   steps and `lgtm-land.sh` never have to guess it, places the worktree flat under
   `<main_root>/.worktrees/<task-slug>`, copies `.env` in, and syncs the uv workspace if the
   project has a `uv.lock`. It prints the worktree path on stdout, and fails closed if the base
   is not a local branch.

   Re-running is safe: an existing worktree is reused and an existing branch gets one attached.
   stderr says `created`, `attached to existing branch`, or `reusing worktree` — on anything
   but `created` you are resuming existing work, so read the branch's diff against its base
   before assuming a clean slate.

   Then switch your session into it — Claude Code: `EnterWorktree` with **`name`** set to
   `<prefix>/<task-slug>` and **no `path`**. The `WorktreeCreate` hook resolves the worktree the
   script just made and Claude Code enters it.

   Pass `name`, never `path`. They reach the same worktree, but a model-supplied `path` outside
   `.claude/worktrees/` relocates the permission root and so raises an approval prompt every
   single time; `name` goes through the hook and raises none.

3. **Give the worktree its own database, if the project has per-branch databases.** How that is
   done is the project's business, not this skill's — check the repo for guidance. Drive the
   project's own audited command; never the database provider's CLI by hand. If the project
   provisions nothing, skip this step.

## Project-specific additions

Skills do not compose — a project skill of the same name is **shadowed** by this one, and a
personal skill always wins — so project guidance cannot live in a project `leaf` skill. This
skill declares an extension point instead:

- **If `.claude/leaf.md` exists in the repo, read it and follow it.** It holds whatever this
  project needs that the generic flow cannot know: how to provision and drop a branch database,
  extra setup steps, local package wiring, caveats. Treat it as an addendum to these
  instructions, not a replacement.

Note that sometimes you may depend on local packages outside of the repo you're working on. In such situations, I should have already added a copy of that package to `.worktrees/`. If I haven't, find the package on this machine — wherever repos are kept locally, typically a sibling of the repo you are in — and copy it into `.worktrees/`.

## Investigation

4. Add logs freely and run executions to deeply understand the situation before making codebase changes. If necessary, spend a lot of time on this step.
   - As an LLM you can't see things like browser executions. Make up for this gap by adding comprehensive logging, analysis of results, etc. — signals available to you as a command line program.
   - Investigate, investigate, INVESTIGATE. The user will provide plenty of autonomous scope. Speed of implementation is not a concern.

## TDD

5. **Invoke the `tdd` skill via the Skill tool** (not a hand-rolled version — see the note
   below). It turns the investigation into tests that are gated and committed before any
   implementation — red for new behaviour, pinned green for a refactor. Those tests are what
   "done" means for the rest of this leaf, and its guard hook will block implementation edits
   until they exist.

## Implementation

6. Make codebase changes to resolve the issue or add the feature, driving the red tests green.
7. Test the fix or feature comprehensively beyond the pinned tests. Question thoroughly if it has been implemented correctly. Consider boundary cases.
8. **Invoke the `contact` skill via the Skill tool** to audit how much contact with reality the work has actually had — concrete execution against real data, end-to-end runs, observed logs/metrics — versus what's still only theoretical. Action any cheap, reversible next touches to de-risk the work before it reaches the user.
9. **Invoke the `vocab` skill via the Skill tool** to curate `.library/VOCAB.md` against the work just done — capture any new domain terms the implementation coined, reconcile any usage that drifted from an existing definition, and settle fuzzy or overloaded words.
10. **Invoke the `reflect` skill via the Skill tool** — the pre-user-input review: it spawns an unbiased read-only review of the work against the original intent, then triages the findings and actions what survives.

> **Steps 5, 8, 9 and 10 mean the Skill tool — not your own approximation of them.**
> Each of these skills carries a method you cannot reconstruct from its name. `reflect` is the
> one that bites: its judge is a **different Claude model** (opus reflects with sonnet, sonnet
> and fable reflect with opus), because a same-model reviewer shares your blind spots — which is
> the entire reason the step exists. Spawning a same-model reviewer looks like reflecting and
> isn't. If a step names a skill, load the skill.

11. After actioning the contact, vocab, and reflection findings, write a self-criticism of the work:
   - Code form and structure (are the patterns clean, maintainable and efficient?)
   - Solution — is it a patch, or a direct, comprehensive fix?

## Completion

12. Remove all debug logs.
13. Write `.library/forks/{index}-{task-slug}.md` documenting:
    - **Date**
    - **Problem:** what the issue or goal was
    - **Investigation:** what you found during exploration (omit if no investigation was needed)
    - **Solution:** the approach taken and why — no excessive code. Function/class signatures with comments are acceptable.
    - **Implementation:** key files/functions changed and how — no excessive code (the user can see the diff)
    - **Self-criticism:** include a section critiquing the work
    - **Test results:** what was run, what passed. How do you know the problem is fixed?
14. Commit all changes (including the library doc) and push the branch.
15. Your final message — presented while awaiting the user's review — takes these headings, in this order:

    ```
    # Motivation
    # Summary of Work & Outcomes
    # Reality Contact
    # How to Review
    ## Concept Core
    ## Worth Scrutiny
    ```

    Open with a one-line diff scale against the base, so the size of what is being reviewed is
    known before any prose. Read the base back rather than recalling it, and measure from the
    merge-base so a stale base does not inflate the numbers:

    ```
    base=$(git config "branch.$(git branch --show-current).leafBase")
    git diff --shortstat "$(git merge-base "$base" HEAD)" HEAD
    ```

    Render it as: `` `<branch>` vs `<base>` — N files, +X/−Y ``. If the diff is large or lopsided
    (a big deletion, a vendored file, a lockfile churn), say in a clause what accounts for it.

    - **Motivation** — the task as it stood before any of this existed: the problem, and why it was worth doing. The review often happens days later, so assume nothing is remembered. Two or three sentences.
    - **Summary of Work & Outcomes** — what changed, and what it now does that it did not before. The decisions that mattered, with the reasoning. Enough that the work can be judged without reading the whole diff.
    - **Reality Contact** — what was actually executed against real data, end to end, and what was observed: the runs, the logs, the tests, the numbers. Say plainly what remains theoretical.
    - **Concept Core** — read these first, in this order: the two or three classes/modules carrying the shape of the work — the one that owns the new concept, then what it hangs off. A line each on what it is for, with file and line numbers, so the mental model forms before any detail.
    - **Worth Scrutiny** — where a second pair of eyes is wanted: decisions that could reasonably have gone the other way, the seams where this work meets existing code, what the tests do not cover, and the part you are least sure of. Name *what* to check, not just where — the question you would ask if you were reviewing it.

    Do not narrate the whole change again. Finish with the branch name and the CLI command that opens VS Code at the wt folder.

## Rebasing

Often, I will have multiple worktrees in parallel. Because of this, you may need to rebase.
Rebase on the leaf's **own local base branch** — recorded at setup, so read it rather than
assuming `main`:

```
git config "branch.$(git branch --show-current).leafBase"
```

Never rebase on `origin/...`.

## Landing

Do not land the leaf yourself. Stop at step 15 and wait — how a leaf lands varies by
environment, and I will tell you which flow to run when I've reviewed the work.