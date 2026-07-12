---
name: lgtm
description: Conclude a leaf/worktree — rebase on its base, finalise the library doc, merge back, and tear the worktree down. Lands locally by default, or through a GitHub PR with `lgtm pr` (top-level leaves only).
disable-model-invocation: true
---

# lgtm

`lgtm` means the work in this worktree is done — conclude it by merging the leaf back into
**its base** and tearing the worktree down. Adding a `pr` (e.g. `lgtm pr`) does the same but
lands a top-level leaf through a GitHub pull request instead of a local merge. `pr` is just a
recognised suffix, not strict syntax — `lgtm pr`, `lgtm --pr`, or "lgtm, as a PR" all select PR
mode.

The mechanical landing — base lookup, database teardown, squash-merge, worktree removal, and
the push rule — is done by `lgtm-land.sh`, which sits beside this skill. Your job is the
judgement around it: the rebase, the docs, and the messages.

## The base

Every leaf was cut from a *base* and merges back into it: local `main` for a top-level leaf, or
the parent worktree's branch for a sub-worktree. `leaf-setup.sh` recorded it at creation, so you
never have to infer it:

```
~/.claude/skills/lgtm/lgtm-land.sh base <branch>
```

If that errors because no base was recorded, the worktree was not created by `leaf-setup.sh`.
Do not guess — establish the base with the user, then record it with
`git config branch.<branch>.leafBase <base>`.

PR mode applies to **top-level leaves only**. A sub-worktree's base is an unpushed parent
branch, so there is no remote base to open a PR against — refuse PR mode for a sub-worktree,
explain why, and conclude it locally instead.

## Always first

1. Rebase on the local base branch, working through any conflicts. `lgtm-land.sh` refuses to
   land a leaf that is not rebased onto its base — resolving conflicts is yours, not the
   script's.
2. Ensure the `.library/forks/` doc is up to date with any changes since you last touched it,
   and commit it. The worktree must be clean before landing.

## Default — land locally

3. Return the session to the main repo without deleting anything (Claude Code: `ExitWorktree`
   (keep)). The landing deletes the worktree, so do not be standing in it.
4. Land it:

   ```
   ~/.claude/skills/lgtm/lgtm-land.sh land <branch> -m "<summarising commit message>"
   ```

   This drops the leaf's database if the project provisions one, squash-merges into the base,
   removes the worktree, and pushes — but **only when the base is `main`**. A sub-worktree lands
   into its parent and is deliberately not pushed: the parent keeps accumulating its merged
   slices and is pushed when *it* is landed. Pass `--dry-run` first if you want to see the plan.

5. For a sub-worktree, you are done in the main repo — switch back into the parent worktree if
   the user wants to keep working on it.

## PR mode — top-level leaf, land through a PR

In PR mode **GitHub is authoritative**: it advances `origin/main` when it merges the PR, and you
pull main back down — you never push main yourself. Defer teardown until **after** the PR
merges, so that if CI fails the worktree is still intact, with its database live, to fix in.

3. Push the branch: `git push -u origin <branch>`.
4. Open the PR: `gh pr create --base main --fill` (or supply `--title`/`--body` drawn from the
   library doc).
5. Watch CI: `gh pr checks <branch> --watch` — it blocks until checks settle and exits non-zero
   on failure. If it fails, fix in the worktree (still intact), push again, and re-watch.
6. Once green, squash-merge on the server: `gh pr merge <branch> --squash --delete-branch` with a
   summarising `--subject`/`--body`. This marks the PR **merged** and deletes the remote branch.
7. Sync local main: `git switch main && git pull --ff-only`. It fast-forwards cleanly because you
   rebased in step 1 — origin/main is just local main plus the one squash commit. If `--ff-only`
   refuses, someone else advanced main: investigate, don't paper over it.
8. Tear down — the merge already happened on GitHub, so drop the database and remove the
   worktree only:

   ```
   ~/.claude/skills/lgtm/lgtm-land.sh teardown <branch>
   ```

## Why some steps need gh

Creating the PR, watching its checks, and merging it so GitHub marks it **merged** all touch
GitHub-side objects — there is no git equivalent, so they go through `gh`. Doing the squash-merge
locally instead of via `gh pr merge` would leave the PR open forever: the squash commit gets a new
SHA the PR never sees as merged.

## Project-specific additions

Skills do not compose — a project skill of the same name is shadowed by this one — so project
guidance cannot live in a project `lgtm` skill. Instead: **if `.claude/leaf.md` exists in the
repo, read it and follow it.** It is the project's addendum to the leaf lifecycle, covering
whatever the generic flow cannot know.
