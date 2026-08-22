#!/usr/bin/env bash
# Create and provision a leaf worktree. Invoked by the /leaf skill (step 2).
#
#   leaf-setup.sh <prefix>/<slug> [base]    e.g. leaf-setup.sh feat/checkout-retry
#                                                leaf-setup.sh fix/tz-drift release/2.0
#
# Cuts from <base> when given. Otherwise from local `main` when run in the main repo, or
# from HEAD when run inside an existing worktree (a sub-worktree). Prints the absolute
# worktree path to stdout; all progress goes to stderr so callers can capture the path
# cleanly.
#
# Idempotent: re-running against an existing branch attaches a worktree to it, and against
# an existing worktree reuses it. stderr says which of created/attached/reusing happened.

set -euo pipefail

log() { echo "leaf-setup: $*" >&2; }
die() { echo "leaf-setup: error: $*" >&2; exit 1; }

branch="${1:-}"
requested_base="${2:-}"
[ -n "$branch" ] || die "usage: leaf-setup.sh <prefix>/<slug> [base]  (e.g. feat/checkout-retry)"

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"

git_dir=$(git rev-parse --absolute-git-dir)
common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd)
main_root=$(dirname "$common_dir")
source_root=$(git rev-parse --show-toplevel)

slug="${branch##*/}"
worktree_dir="$main_root/.worktrees/$slug"

branch_exists=false
git show-ref --verify --quiet "refs/heads/$branch" && branch_exists=true
recorded_base=$(git -C "$main_root" config --get "branch.$branch.leafBase" || true)

if [ "$branch_exists" = true ]; then
  # For a branch that already exists the base is a fact about its history, not about where
  # this script is being run from — inferring it here could land the leaf in a branch it was
  # never cut from, so take the record or an explicit argument and nothing else.
  if [ -n "$requested_base" ] && [ -n "$recorded_base" ] && [ "$requested_base" != "$recorded_base" ]; then
    die "branch '$branch' is recorded against base '$recorded_base'; refusing to retarget to '$requested_base' (set branch.$branch.leafBase deliberately if that is the intent)"
  fi
  base="${requested_base:-$recorded_base}"
  [ -n "$base" ] || die "branch '$branch' already exists but has no recorded base; pass one: leaf-setup.sh $branch <base>"
elif [ -n "$requested_base" ]; then
  base="$requested_base"
elif [ "$git_dir" = "$common_dir" ]; then
  # In the main repo these are the same path; inside a linked worktree they diverge.
  base="main"
else
  base=$(git rev-parse --abbrev-ref HEAD)
fi

# A leaf is always cut from, rebased on, and landed into a LOCAL branch — an origin/... or
# detached start point would leave lgtm-land.sh with nothing it can merge into.
git show-ref --verify --quiet "refs/heads/$base" || die "base branch '$base' does not exist locally"

worktree_list=$(git -C "$main_root" worktree list --porcelain)
# `worktree list` is the only authority on what $worktree_dir is: a bare leftover directory
# and a registration whose directory was deleted both look identical to a -e test.
registered_ref=$(printf '%s\n' "$worktree_list" | awk -v d="worktree $worktree_dir" '
  $0 == d { found = 1; next }
  found && /^branch / { sub(/^branch /, ""); print; exit }
  found && $0 == "detached" { print "detached"; exit }
  found && /^worktree / { exit }')

if [ -n "$registered_ref" ] && [ ! -d "$worktree_dir" ]; then
  log "pruning stale registration for $worktree_dir"
  git -C "$main_root" worktree prune >&2
  worktree_list=$(git -C "$main_root" worktree list --porcelain)
  registered_ref=""
fi

if [ -n "$registered_ref" ]; then
  [ "$registered_ref" = "refs/heads/$branch" ] ||
    die "$worktree_dir is a worktree of '${registered_ref#refs/heads/}', not '$branch'"
  log "reusing worktree  base=$base  ->  $worktree_dir"
elif [ "$branch_exists" = true ]; then
  [ -e "$worktree_dir" ] && die "$worktree_dir exists but is not a registered worktree"
  holder=$(printf '%s\n' "$worktree_list" | awk -v b="branch refs/heads/$branch" '
    /^worktree / { p = substr($0, 10) }
    $0 == b { print p; exit }')
  [ -n "$holder" ] && die "branch '$branch' is already checked out at $holder"
  log "attaching to existing branch  base=$base  ->  $worktree_dir"
  git -C "$source_root" worktree add "$worktree_dir" "$branch" >&2
else
  [ -e "$worktree_dir" ] && die "$worktree_dir exists but is not a registered worktree"
  log "created  base=$base  ->  $worktree_dir"
  git -C "$source_root" worktree add "$worktree_dir" -b "$branch" "$base" >&2
fi

# Record the base so lgtm-land.sh can land the leaf without having to guess it. Deriving it
# later from history is ambiguous once a leaf is rebased, and guessing wrong would merge a
# sub-worktree into main.
git -C "$main_root" config "branch.$branch.leafBase" "$base"

# .env is gitignored, so it does not come across with the worktree. Never overwrite one that
# is already there — on a reused worktree it holds that branch's own database URL.
if [ -f "$source_root/.env" ] && [ ! -f "$worktree_dir/.env" ]; then
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
