#!/usr/bin/env bash
# Create and provision a leaf worktree. Invoked by the /leaf skill (step 2).
#
#   leaf-setup.sh <prefix>/<slug>     e.g. leaf-setup.sh feat/checkout-retry
#
# Cuts from local `main` when run in the main repo, or from HEAD when run inside an
# existing worktree (a sub-worktree). Prints the absolute worktree path to stdout;
# all progress goes to stderr so callers can capture the path cleanly.

set -euo pipefail

log() { echo "leaf-setup: $*" >&2; }
die() { echo "leaf-setup: error: $*" >&2; exit 1; }

branch="${1:-}"
[ -n "$branch" ] || die "usage: leaf-setup.sh <prefix>/<slug>  (e.g. feat/checkout-retry)"

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"

git_dir=$(git rev-parse --absolute-git-dir)
common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd)
main_root=$(dirname "$common_dir")

# In the main repo these are the same path; inside a linked worktree they diverge.
if [ "$git_dir" = "$common_dir" ]; then
  base="main"
  source_root="$main_root"
else
  base=$(git rev-parse --abbrev-ref HEAD)
  source_root=$(git rev-parse --show-toplevel)
fi

slug="${branch##*/}"
worktree_dir="$main_root/.worktrees/$slug"

[ -e "$worktree_dir" ] && die "$worktree_dir already exists"
git show-ref --verify --quiet "refs/heads/$branch" && die "branch '$branch' already exists"

log "base=$base  ->  $worktree_dir"
git -C "$source_root" worktree add "$worktree_dir" -b "$branch" "$base" >&2

# Record the base so lgtm-land.sh can land the leaf without having to guess it. Deriving it
# later from history is ambiguous once a leaf is rebased, and guessing wrong would merge a
# sub-worktree into main.
git -C "$main_root" config "branch.$branch.leafBase" "$base"

# .env is gitignored, so it does not come across with the worktree.
if [ -f "$source_root/.env" ]; then
  cp "$source_root/.env" "$worktree_dir/.env"
  log "copied .env"
fi

# A plain `uv run` syncs only the root, leaving workspace members missing for the first
# command.
if [ -f "$worktree_dir/uv.lock" ]; then
  log "uv sync --all-packages"
  (cd "$worktree_dir" && uv sync --all-packages) >&2
fi

echo "$worktree_dir"
