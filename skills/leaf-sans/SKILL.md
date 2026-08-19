---
name: leaf-sans
description: The light leaf — an isolated worktree with its own database branch, implement, test, audit contact with reality, push. No TDD gate, no reflect, no fork document. Cut from local main, or off the current worktree when run from inside one. Use for work small enough that the full /leaf ceremony would cost more than the change.
---

# leaf-sans

Isolated worktree for a small task. `$ARGUMENTS` describes it.

This is `/leaf` stripped to the worktree, the change, and the proof it works. It
deliberately drops the TDD gate, the `vocab` and `reflect` passes, the self-criticism,
the fork document, and the six-heading report. If partway through the work turns out to be larger than it
looked — a new domain concept, a fix you can't explain, anything touching more than a
seam or two — stop and run `/leaf` instead. The worktree you're in is already the right
one for it.

**The base.** Every leaf has a *base* — the branch it is cut from and merged back into:

- **In the main repo** → the base is local `main`.
- **Inside an existing worktree** → the base is *that worktree's branch*, and the new leaf
  is a sub-worktree merged back into the parent, not main.

## Setup

1. Derive a `<task-slug>` from the task, prefixed `feat/`, `fix/` or `chore/`.
2. Create the worktree with `/leaf`'s script — it is the one owner of this step:

   ```
   ~/.claude/skills/leaf/leaf-setup.sh <prefix>/<task-slug>
   ```

   It infers the base from where you are, places the worktree at
   `<main_root>/.worktrees/<task-slug>`, copies `.env` in, syncs the uv workspace if there
   is a `uv.lock`, prints the path, and fails closed if the path or branch already exists.

   Then enter it — Claude Code: `EnterWorktree` with **`name`** set to
   `<prefix>/<task-slug>` and **no `path`**. Pass `name`, never `path`: a model-supplied
   path relocates the permission root and prompts for approval every time.

3. **Give the worktree its own database, if the project has per-branch databases.** Drive
   the project's own audited command, never the provider's CLI by hand. If the project
   provisions nothing, skip.
4. **If `.claude/leaf.md` exists in the repo, read it and follow it.** It holds the
   project-specific setup this skill cannot know — branch database provisioning, local
   package wiring, caveats. It applies here exactly as it does to `/leaf`.

## Work

5. Understand the cause before changing anything. Enough to explain *why* the fix works —
   not the exhaustive investigation `/leaf` asks for, but never a guess that happens to pass.
6. Make the change.
7. Test it. Existing suite plus whatever pins the new behaviour — a small task still leaves
   behind a test that would catch the bug coming back.
8. **Invoke the `contact` skill via the Skill tool** — not your own approximation of it. It
   audits what the work has actually been executed against versus what is still theory, and
   names the cheapest next touch. Action any cheap, reversible one before handing back.
9. Remove debug logs, commit, push.

## Report

10. Final message, three short paragraphs — no headings, no re-narration of the diff:

   - **What and why** — the problem as it stood, and what now happens instead.
   - **What was actually run** — the commands, tests and observed output. Say plainly what
     is still theoretical.
   - **Where to look** — the one or two files carrying the change, with line numbers, and
     the single thing most worth a second pair of eyes.

   Finish with the branch name and the CLI command that opens VS Code at the worktree.

## Rebasing and landing

Rebase on the **local base branch** — the parent worktree's branch for a sub-worktree,
otherwise local `main` — never on `origin/...`. Do not land the leaf yourself; stop at
step 10 and wait.
