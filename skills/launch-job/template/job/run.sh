#!/usr/bin/env zsh
# __JOB__ — TODO: one line on what this job does.
#
# The *logic* lives in the owning project; this is only the execution wrapper.
# ONE-SHOT: do one unit of work and exit. Never add an internal `while true; sleep`
# loop — launchd owns the schedule (see __LABEL__.plist) and runs this fresh
# every interval, which already guarantees one instance at a time.
#
# Point at the ROOT repo, never a worktree: a worktree can be deleted by `lgtm`, and
# a launchd job pointed into a deleted directory fails silently, forever.
set -euo pipefail
source "${0:A:h}/../lib/common.sh"

# launchd hands us a minimal PATH; spell out where uv/git/etc live.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"

# Shell-only env (e.g. PROJECT_ROOT) frozen at `make start`. The job name is this
# script's parent dir.
env_file="$HOME/.cache/jobs/${0:A:h:t}.env"
[[ -f "$env_file" ]] && source "$env_file"

log "__JOB__: tick"
cd __REPO__
exec __COMMAND__
