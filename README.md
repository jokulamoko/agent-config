# agent-config

Portable, agent-agnostic harness configuration, synced across devices. Cloned into `~/.agents`.

Each agent gets the config linked into wherever it expects to read it — `install-claude.sh` does 
that for Claude Code, given it doesn't read `.agents/skills`. 

## Contents

| Path | What |
|---|---|
| `AGENTS.md` | Global instructions: principles, development standards, conversation style. |
| `skills/` | The skills. `SKILL.md` per skill, plus any scripts it owns. |
| `bin/` | Shared scripts that belong to no single skill. |
| `install-claude.sh` | Links `skills/` and `AGENTS.md` into `~/.claude`. |

A skill that needs to know something about a particular repo declares an extension point instead —
`/leaf` and `/lgtm` read `.claude/leaf.md` from the repo they are run in.

## Installing for Claude Code

```sh
~/.agents/install-claude.sh            # --dry-run to preview
```

Idempotent. Every `skills/<name>` becomes a symlink at `~/.claude/skills/<name>`, and `AGENTS.md`
becomes `~/.claude/CLAUDE.md`. Re-run after adding, renaming, or deleting a skill — stale links into
this repo are pruned. It refuses to replace a real file or directory, so anything Claude-only that
already lives in `~/.claude` — `settings.json`, `skills/synced/` — is left untouched.

Skills reference their own scripts as `~/.claude/skills/<name>/<script>`, which resolves through the
symlink, so permission rules and hook commands keep working unchanged.

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

```sh
git clone git@github.com:jokulamoko/agent-config.git ~/.agents
~/.agents/install-claude.sh
```

Git hooks are not cloned. To keep branches local and only ever push `main`, reinstall the
`pre-push` guard in `.git/hooks/` on each machine.
