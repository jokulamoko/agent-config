# agent-config

Portable Agent harness configuration, synced across devices. Cloned into `~/.claude`.

Only the config is tracked — `.gitignore` denies everything and allow-lists back in. Runtime
state (sessions, history, caches, projects) stays local.

## Contents

| Path | What |
|---|---|
| `CLAUDE.md` | Global instructions: principles, development standards, conversation style. |
| `settings.json` | Permissions, model, hooks. Allow rules are generic; project-specific ones live in that project's `.claude/settings.json`. |
| `skills/` | The skills. `SKILL.md` per skill, plus any scripts it owns. |

Nothing here is project-specific. A skill that needs to know something about a particular repo
declares an extension point instead — `/leaf` and `/lgtm` read `.claude/leaf.md` from the repo
they are run in.

## The leaf workflow

`/leaf` cuts an isolated worktree to work in; `/lgtm` lands it back. Two scripts do the
mechanical parts:

- `skills/leaf/leaf-setup.sh <prefix>/<slug>` — create the worktree, infer its base (local `main`,
  or the current branch's `HEAD` when run inside a worktree, making a sub-worktree), copy `.env`
  in, sync the uv workspace if there is a `uv.lock`, and record the base.
- `skills/lgtm/lgtm-land.sh land|teardown|base <branch>` — squash-merge the leaf into its recorded
  base, drop its database branch, remove the worktree, and push only when the base is `main`.

Both are provider-agnostic: they probe for a `db.refresh` / `db.drop` make target rather than
assuming any particular database. A project without one skips those steps.

## On a new device

`~/.claude` already exists and holds local state, so it cannot be cloned into directly:

```sh
cd ~/.claude
git init && git remote add origin git@github.com:jokulamoko/agent-config.git
git fetch origin && git checkout -f main
```

This overwrites the tracked files and leaves everything else alone.

Git hooks are not cloned. To keep branches local and only ever push `main`, reinstall the
`pre-push` guard in `.git/hooks/` on each machine.
