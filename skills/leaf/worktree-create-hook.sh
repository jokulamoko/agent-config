#!/usr/bin/env bash
# WorktreeCreate hook. Claude Code calls this when a session asks it to create a worktree by name
# (EnterWorktree without a `path`), and enters whatever absolute path we print to stdout. That is
# how a leaf stays in `<main_root>/.worktrees/` and still skips the permission-root approval
# prompt, which a model-supplied `path` outside `.claude/worktrees/` always raises.
#
# Contract: {"hook_event_name":"WorktreeCreate","name":"<prefix>/<slug>"} on stdin;
# the worktree path on stdout; everything else on stderr.
#
# /leaf runs leaf-setup.sh itself first, so the usual job here is to RESOLVE that worktree, not
# create one. Resolving is also what keeps the base honest: Claude Code runs this hook from the
# main repo root even when the session sits inside a worktree (the payload's `cwd` is normalised
# to it too), so a worktree created here could only ever be cut from `main` — which would silently
# mis-base a sub-worktree. leaf-setup.sh run from the session sees the real cwd and gets it right.
#
# The create path below therefore serves only callers that never ran the script — chiefly agent
# worktrees (Agent `isolation: "worktree"`), which route through this same hook.

set -euo pipefail

name=$(jq -er '.name')
here=$(dirname "${BASH_SOURCE[0]}")

common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd)
main_root=$(dirname "$common_dir")
worktree_dir="$main_root/.worktrees/${name##*/}"

if git -C "$main_root" worktree list --porcelain | grep -qxF "worktree $worktree_dir"; then
  echo "worktree-create-hook: resolved existing $worktree_dir" >&2
  echo "$worktree_dir"
  exit 0
fi

echo "worktree-create-hook: no worktree at $worktree_dir — creating one (base: main)" >&2
exec "$here/leaf-setup.sh" "$name"
