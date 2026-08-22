---
name: leaf-sans
description: "/leaf without the documentation — isolated worktree with its own database branch, full investigation, TDD gate, contact and reflect passes, push. Code only: no VOCAB curation, no .library/forks/ document. Cut from local main, or off the current worktree when run from inside one. Use when the change deserves the full rigour but leaves nothing worth writing down."
---

# leaf-sans

Create an isolated worktree to work on a task. `$ARGUMENTS` describes the task.

This is `/leaf` **sans documentation**. Every gate stays — investigation, TDD, contact,
reflect, self-criticism. What it drops is the writing that outlives the branch: the `vocab`
pass over `.library/VOCAB.md`, and the `.library/forks/` fork document. Use it when the work
coins no domain term and leaves nothing a future reader would want narrated. If partway
through the work turns out to want a record — a new concept, an investigation whose findings
matter beyond this diff — stop and run `/leaf` instead. The worktree you're in is already the
right one for it.

**The base.** Every leaf has a *base* — the branch it is cut from and will eventually
merge back into. Determine it from where you are when invoked:

- **In the main repo** → the base is local `main`. The default case, unchanged.
- **Inside an existing worktree** → the base is *that worktree's branch*. The new leaf is
  a **sub-worktree**: cut from the parent's current HEAD and merged back into the parent
  (not main) when it lands.

Throughout the steps below, "the base" means this branch.

## Grill

I may request `/grill-me` specifically up front to interrogate the task — surfacing
hidden assumptions, missing scope, and the edge cases that the bare description glosses
over. But it shouldn't be always triggered; only run it when I ask for it.

## Setup

1. Derive a `<task-slug>` from the task description, using a `feat/`, `fix/`, or `chore/` prefix depending on the nature of the task.
2. Create the worktree with `/leaf`'s script — it is the one owner of this step. Run it from
   anywhere in the repo:

   ```
   ~/.claude/skills/leaf/leaf-setup.sh <prefix>/<task-slug>
   ```

   It infers the base from where you are — local `main` in the main repo, the current branch's
   `HEAD` inside a worktree — places the worktree flat under `<main_root>/.worktrees/<task-slug>`,
   copies `.env` in, and syncs the uv workspace if the project has a `uv.lock`. It prints the
   worktree path on stdout. Re-running is safe: an existing worktree is reused and an existing
   branch gets one attached. stderr says `created`, `attached to existing branch`, or `reusing
   worktree` — on anything but `created` you are resuming existing work, so read the branch's
   diff against its base first.

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
9. **Invoke the `reflect` skill via the Skill tool** — the pre-user-input review: it spawns an unbiased read-only review of the work against the original intent, then triages the findings and actions what survives.

> **Steps 5, 8 and 9 mean the Skill tool — not your own approximation of them.**
> Each of these skills carries a method you cannot reconstruct from its name. `reflect` is the
> one that bites: its judge is a **different Claude model** (opus reflects with sonnet, sonnet
> and fable reflect with opus), because a same-model reviewer shares your blind spots — which is
> the entire reason the step exists. Spawning a same-model reviewer looks like reflecting and
> isn't. If a step names a skill, load the skill.

10. After actioning the contact and reflection findings, write a self-criticism of the work — in your final message, not a file:
   - Code form and structure (are the patterns clean, maintainable and efficient?)
   - Solution — is it a patch, or a direct, comprehensive fix?

## Completion

11. Remove all debug logs.
12. Commit all changes and push the branch. Write no `.library/` document — the diff, the
    tests and the report below are the whole record.
13. Your final message — presented while awaiting the user's review — takes these headings, in this order:

    ```
    # Motivation
    # Summary of Work & Outcomes
    # Reality Contact
    # How to Review
    ## Concept Core
    ## Worth Scrutiny
    ```

    - **Motivation** — the task as it stood before any of this existed: the problem, and why it was worth doing. The review often happens days later, so assume nothing is remembered. Two or three sentences.
    - **Summary of Work & Outcomes** — what changed, and what it now does that it did not before. The decisions that mattered, with the reasoning. Enough that the work can be judged without reading the whole diff.
    - **Reality Contact** — what was actually executed against real data, end to end, and what was observed: the runs, the logs, the tests, the numbers. Say plainly what remains theoretical.
    - **Concept Core** — read these first, in this order: the two or three classes/modules carrying the shape of the work — the one that owns the new concept, then what it hangs off. A line each on what it is for, with file and line numbers, so the mental model forms before any detail.
    - **Worth Scrutiny** — where a second pair of eyes is wanted: decisions that could reasonably have gone the other way, the seams where this work meets existing code, what the tests do not cover, and the part you are least sure of. Name *what* to check, not just where — the question you would ask if you were reviewing it. Fold the self-criticism from step 10 in here.

    Do not narrate the whole change again. Finish with the branch name and the CLI command that opens VS Code at the wt folder.

## Rebasing

Often, I will have multiple worktrees in parallel. Because of this, you may need to rebase.
Rebase on the **local base branch** — the parent worktree's branch for a sub-worktree,
otherwise local `main` — never on `origin/...`.

## Landing

Do not land the leaf yourself. Stop at step 13 and wait — how a leaf lands varies by
environment, and I will tell you which flow to run when I've reviewed the work.
