#!/usr/bin/env bash
# Land or tear down a leaf worktree. Invoked by the /lgtm skill.
#
#   lgtm-land.sh land <branch> -m <message>   squash-merge into its base, then tear down
#   lgtm-land.sh teardown <branch>            drop the database and remove the worktree only
#   lgtm-land.sh base <branch>                print the branch's base
#
#   -n, --dry-run    print the plan, change nothing
#       --no-push    never push, even when the base is main
#
# Run from the main repo (exit the worktree first — this deletes it).
#
# Knows nothing about any database provider. It probes for a `db.drop` make target and calls
# it if present; a project without one simply skips that step.

set -euo pipefail

log() { echo "lgtm-land: $*" >&2; }
die() { echo "lgtm-land: error: $*" >&2; exit 1; }
run() { if [ "$dry_run" = true ]; then echo "  would run: $*" >&2; else "$@"; fi; }

mode="${1:-}"; shift || true
branch="${1:-}"; shift || true
message=""
dry_run=false
no_push=false

while [ $# -gt 0 ]; do
  case "$1" in
    -m|--message) message="${2:-}"; shift 2 ;;
    -n|--dry-run) dry_run=true; shift ;;
    --no-push)    no_push=true; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

case "$mode" in land|teardown|base) ;; *) die "usage: lgtm-land.sh land|teardown|base <branch> [-m <message>]" ;; esac
[ -n "$branch" ] || die "no branch given"
git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"
git show-ref --verify --quiet "refs/heads/$branch" || die "no such branch: $branch"

common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd)
main_root=$(dirname "$common_dir")

# leaf-setup.sh records this at creation. Absent for worktrees made before that, or by hand.
base=$(git -C "$main_root" config --get "branch.$branch.leafBase" || true)
[ -n "$base" ] || die "no recorded base for '$branch' (branch.$branch.leafBase unset).
  This leaf predates lgtm-land.sh, or was not created by leaf-setup.sh. Land it by hand, or
  set the base explicitly:  git config branch.$branch.leafBase <main|parent-branch>"
git show-ref --verify --quiet "refs/heads/$base" || die "base branch '$base' no longer exists"

if [ "$mode" = base ]; then echo "$base"; exit 0; fi

worktree_path=$(git worktree list --porcelain \
  | awk -v b="refs/heads/$branch" '/^worktree /{p=substr($0,10)} /^branch /{if ($2==b) print p}')
[ -n "$worktree_path" ] || die "no live worktree checked out for '$branch'"

base_root=$(git worktree list --porcelain \
  | awk -v b="refs/heads/$base" '/^worktree /{p=substr($0,10)} /^branch /{if ($2==b) print p}')
[ -n "$base_root" ] || die "base '$base' is not checked out in any worktree — cannot merge into it"

[ -z "$(git -C "$worktree_path" status --porcelain)" ] || die "worktree has uncommitted changes: $worktree_path"

if [ "$mode" = land ]; then
  [ -n "$message" ] || die "land requires -m <message>"
  # A leaf must be rebased onto its base before landing, so the squash sits on current history.
  git -C "$worktree_path" merge-base --is-ancestor "$base" "$branch" \
    || die "'$branch' is not rebased onto '$base' — rebase it first (resolve any conflicts by hand)"
fi

log "branch=$branch  base=$base"
log "worktree=$worktree_path"
[ "$dry_run" = true ] && log "DRY RUN — nothing will change"

# Capability probe, not an assumption: projects without a db.drop target skip this entirely.
if make -C "$worktree_path" -n db.drop >/dev/null 2>&1; then
  log "dropping database branch via 'make db.drop'"
  run make -C "$worktree_path" db.drop "branch=$branch"
else
  log "no db.drop target — skipping database teardown"
fi

if [ "$mode" = land ]; then
  log "squash-merging '$branch' into '$base' at $base_root"
  run git -C "$base_root" merge --squash "$branch"
  run git -C "$base_root" commit -m "$message"
fi

log "removing worktree $worktree_path"
run git worktree remove "$worktree_path"

# A sub-worktree's base is an unpushed parent branch — it keeps accumulating slices and is
# pushed only when it is itself landed.
if [ "$mode" = land ] && [ "$base" = "main" ] && [ "$no_push" = false ]; then
  log "pushing $base"
  run git -C "$base_root" push
elif [ "$mode" = land ]; then
  log "not pushing (base is '$base')"
fi

log "done"
