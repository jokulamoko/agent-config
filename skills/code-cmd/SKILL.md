---
name: code-cmd
description: Run and return the command for opening a worktree in VS Code, so the user can inspect the branch
---

If working on a /leaf or worktree, return the VS code command for opening the worktree folder

e.g.

`code /Users/some-user/some-project/.worktrees/some-feature`

Do not say anything else.

## When to run vs. just return

- When this skill is invoked directly (e.g. `/code-cmd`): in addition to returning the code command in the chat, actually run it.
- When invoked as part of `/leaf`: do not run it — just return the command in the chat.
