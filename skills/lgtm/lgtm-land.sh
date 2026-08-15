#!/usr/bin/env bash
# Land or tear down a leaf worktree. Invoked by the /lgtm skill.
#
#   lgtm-land.sh land <branch> -m <message>   verify, squash-merge into its base, push, tear down
#   lgtm-land.sh teardown <branch>            drop the database and remove the worktree only
#   lgtm-land.sh base <branch>                print the branch's base
#
#   -n, --dry-run      print the plan, change nothing
#       --no-push      never push, even when the base is main
#       --skip-checks  land without running `make check` (escape hatch, logged loudly)
#       --force        teardown without proof the PR merged
#
# Run from the main repo (exit the worktree first — this deletes it).
#
# Knows nothing about any database provider or test runner: the project declares both as make
# targets, `db.drop` and `check`, and this probes for them. A missing `check` fails closed —
# unverified work never lands by accident.
#
# Nothing is destroyed until the work is safely landed: verify, merge, push, and only then drop
# the database and remove the worktree.

set -euo pipefail

log() { echo "lgtm-land: $*" >&2; }
die() { echo "lgtm-land: error: $*" >&2; exit 1; }
run() { if [ "$dry_run" = true ]; then echo "  would run: $*" >&2; else "$@"; fi; }
has_target() { make -C "$1" -n "$2" >/dev/null 2>&1; }

mode="${1:-}"; shift || true
branch="${1:-}"; shift || true
message=""
dry_run=false
no_push=false
skip_checks=false
force=false

while [ $# -gt 0 ]; do
  case "$1" in
    -m|--message) message="${2:-}"; shift 2 ;;
    -n|--dry-run) dry_run=true; shift ;;
    --no-push)     no_push=true; shift ;;
    --skip-checks) skip_checks=true; shift ;;
    --force)       force=true; shift ;;
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

[ -z "$(git -C "$worktree_path" status --porcelain)" ] || die "worktree has uncommitted changes: $worktree_path"

if [ "$mode" = land ]; then
  [ -n "$message" ] || die "land requires -m <message>"

  base_root=$(git worktree list --porcelain \
    | awk -v b="refs/heads/$base" '/^worktree /{p=substr($0,10)} /^branch /{if ($2==b) print p}')
  [ -n "$base_root" ] || die "base '$base' is not checked out in any worktree — cannot merge into it"

  # `git commit` after `merge --squash` commits the whole index, so anything already staged in the
  # base would be swept into the squash commit.
  [ -z "$(git -C "$base_root" status --porcelain)" ] \
    || die "base worktree '$base' has uncommitted changes: $base_root
  Commit or stash them — otherwise they land inside the squash commit."

  # A leaf must be rebased onto its base before landing, so the squash sits on current history.
  git -C "$worktree_path" merge-base --is-ancestor "$base" "$branch" \
    || die "'$branch' is not rebased onto '$base' — rebase it first (resolve any conflicts by hand)"
fi

log "branch=$branch  base=$base"
log "worktree=$worktree_path"
[ "$dry_run" = true ] && log "DRY RUN — nothing will change"

has_origin=false
git -C "$main_root" remote get-url origin >/dev/null 2>&1 && has_origin=true

if [ "$mode" = land ] && [ "$base" = "main" ] && [ "$has_origin" = true ]; then
  log "fetching origin to confirm '$base' is current"
  git -C "$main_root" fetch origin "$base" --quiet
  if git -C "$main_root" show-ref --verify --quiet "refs/remotes/origin/$base"; then
    git -C "$main_root" merge-base --is-ancestor "origin/$base" "$base" \
      || die "local '$base' is behind origin/$base — someone else landed first.
  Pull '$base', rebase '$branch' onto it, re-run the checks, then land again."
  fi
fi

if [ "$mode" = teardown ] && [ "$force" = false ]; then
  # PR mode squash-merges on GitHub, so the leaf's commits are never ancestors of main — only the
  # PR's own state proves the work landed.
  command -v gh >/dev/null 2>&1 || die "gh not available, so the PR's merge cannot be confirmed.
  Confirm the PR merged, then re-run with --force."
  pr_state=$(gh pr view "$branch" --json state --jq .state 2>/dev/null || true)
  [ "$pr_state" = "MERGED" ] \
    || die "no merged PR for '$branch' (state: ${pr_state:-none}) — refusing to tear down unlanded work.
  Merge the PR first, or re-run with --force if the work landed some other way."
  log "PR for '$branch' is merged"
fi

if [ "$mode" = land ]; then
  if [ "$skip_checks" = true ]; then
    log "WARNING: --skip-checks — landing '$branch' without running the project's gate"
  elif has_target "$worktree_path" check; then
    log "running 'make check' in the worktree"
    run make -C "$worktree_path" check
  else
    die "no 'check' target in $worktree_path — refusing to land unverified work.
  Declare the project's gate (tests, type checks, lint) as a single make target:
      check:  ## Everything that must pass before a leaf lands
  or land explicitly unverified with --skip-checks."
  fi

  log "squash-merging '$branch' into '$base' at $base_root"
  run git -C "$base_root" merge --squash "$branch"
  run git -C "$base_root" commit -m "$message"

  # A sub-worktree's base is an unpushed parent branch — it keeps accumulating slices and is
  # pushed only when it is itself landed.
  if [ "$base" = "main" ] && [ "$no_push" = false ] && [ "$has_origin" = true ]; then
    log "pushing $base"
    run git -C "$base_root" push
  else
    log "not pushing (base is '$base')"
  fi
fi

# Teardown only after the work is landed: a failure above leaves the worktree and its database
# intact to fix in.
if has_target "$worktree_path" db.drop; then
  log "dropping database branch via 'make db.drop'"
  run make -C "$worktree_path" db.drop "branch=$branch"
else
  log "no db.drop target — skipping database teardown (leaks a branch database if this project provisions one)"
fi

log "removing worktree $worktree_path"
run git worktree remove "$worktree_path"

log "done"
