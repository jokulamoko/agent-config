---
name: leaf
description: Create an isolated worktree branch with its own database branch, investigate thoroughly, implement changes, document in .library/forks/, and push — cut from local main, or off the current worktree when run from inside one. Use when starting a bug fix, feature, or refactor that needs isolation, including slicing a /decompose unit off a larger feature worktree.
---

# Leaf

Create an isolated worktree to work on a task. `$ARGUMENTS` describes the task.

**The base.** Every leaf has a *base* — the branch it is cut from and will eventually
merge back into. Determine it from where you are when invoked:

- **In the main repo** → the base is local `main`. The default case, unchanged.
- **Inside an existing worktree** → the base is *that worktree's branch*. The new leaf is
  a **sub-worktree**: cut from the parent's current HEAD and merged back into the parent
  (not main) at `lgtm`. This is how you slice a `/decompose` unit off a larger feature
  worktree without disturbing it, and how sub-slices stack up before the parent itself
  lands on main.

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
   ~/.claude/skills/leaf/leaf-setup.sh <prefix>/<task-slug>
   ```

   It infers the base from where you are — local `main` in the main repo, the current branch's
   `HEAD` inside a worktree — places the worktree flat under `<main_root>/.worktrees/<task-slug>`,
   copies `.env` in, and syncs the uv workspace if the project has a `uv.lock`. It prints the
   worktree path on stdout and fails closed if that path or branch already exists. Switch your
   session into the printed path (Claude Code: `EnterWorktree` with that `path`).
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

Note that sometimes you may depend on local packages outside of the repo you're working on. In such situations, I should have already added a copy of that package to `.worktrees/`. If I haven't, find the package in my system (probably in `~/projects`) and copy it into `.worktrees/`.

## Investigation

4. Add logs freely and run executions to deeply understand the situation before making codebase changes. If necessary, spend a lot of time on this step.
   - As an LLM you can't see things like browser executions. Make up for this gap by adding comprehensive logging, analysis of results, etc. — signals available to you as a command line program.
   - Investigate, investigate, INVESTIGATE. The user will provide plenty of autonomous scope. Speed of implementation is not a concern.

## Plan

5. From the investigation, develop an implementation plan — the approach, the files it
   touches, the order of work, and the boundary cases it must hold.
6. **Invoke the `reflect` skill via the Skill tool** (not a hand-rolled reviewer — see the
   note below) on the plan: it spawns an unbiased read-only review of the plan against
   the original intent, then triages the findings. Fold what survives back into the plan
   before writing any code — catching a wrong approach here is far cheaper than catching it
   after implementation.

## Implementation

7. Make codebase changes to resolve the issue or add the feature.
8. Test the fix or feature comprehensively. Question thoroughly if it has been implemented correctly. Consider boundary cases.
9. **Invoke the `contact` skill via the Skill tool** to audit how much contact with reality the work has actually had — concrete execution against real data, end-to-end runs, observed logs/metrics — versus what's still only theoretical. Action any cheap, reversible next touches to de-risk the work before it reaches the user.
10. **Invoke the `vocab` skill via the Skill tool** to curate `.library/VOCAB.md` against the work just done — capture any new domain terms the implementation coined, reconcile any usage that drifted from an existing definition, and settle fuzzy or overloaded words.
11. **Invoke the `reflect` skill via the Skill tool** — the pre-user-input review: it spawns an unbiased read-only review of the work against the original intent, then triages the findings and actions what survives.

> **Steps 6, 9, 10 and 11 mean the Skill tool — not your own approximation of them.**
> Each of these skills carries a method you cannot reconstruct from its name. `reflect` is the
> one that bites: its default judge is a **different engine** (headless `opencode`, via
> `reflect/eval.sh`), because a same-model sub-agent shares your blind spots — which is the
> entire reason the step exists. Spawning a same-model reviewer with the Agent tool looks like
> reflecting and isn't. If a step names a skill, load the skill.

12. After actioning the contact, vocab, and reflection findings, write a self-criticism of the work:
   - Code form and structure (are the patterns clean, maintainable and efficient?)
   - Solution — is it a patch, or a direct, comprehensive fix?

## Completion

13. Remove all debug logs.
14. Write `.library/forks/{index}-{task-slug}.md` documenting:
    - **Date**
    - **Problem:** what the issue or goal was
    - **Investigation:** what you found during exploration (omit if no investigation was needed)
    - **Solution:** the approach taken and why — no excessive code. Function/class signatures with comments are acceptable.
    - **Implementation:** key files/functions changed and how — no excessive code (the user can see the diff)
    - **Self-criticism:** include a section critiquing the work
    - **Test results:** what was run, what passed. How do you know the problem is fixed?
15. Commit all changes (including the library doc) and push the branch.
16. In your final message — the summary you present while awaiting the user's review — explain the key changes: what changed, why, and the decisions that mattered, so the user can judge the work without reading the whole diff. Then report the name of the branch and the CLI command that opens VS Code at the wt folder.

## Rebasing

Often, I will have multiple worktrees in parallel. Because of this, you may need to rebase.
Rebase on the **local base branch** — the parent worktree's branch for a sub-worktree,
otherwise local `main` — never on `origin/...`.

## lgtm

When the user writes `lgtm` (or `lgtm pr`), the work is done — conclude the leaf with the
**`lgtm` skill**. It rebases on the base, finalises the library doc, drops the leaf's
database branch, merges the leaf back into its base, and removes the worktree. The default lands a
leaf locally (squash-merge into the base, then push for a top-level leaf); adding `pr`
lands a top-level leaf through a GitHub PR instead — push, open the PR, watch CI, and merge
via `gh` once green, with GitHub advancing origin/main and local main pulled back down.