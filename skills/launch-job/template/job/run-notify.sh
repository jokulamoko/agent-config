#!/usr/bin/env zsh
# __JOB__ — TODO: one line on what this job does.
#
# The *logic* lives in the owning project; this is only the execution wrapper.
# ONE-SHOT: do one unit of work and exit. launchd owns the schedule (see
# __LABEL__.plist).
#
# NOTE: no `exec`. This job must outlive its own command to inspect the exit status
# and notify — `exec` would replace this shell and take the failure path with it.
#
# Point at the ROOT repo, never a worktree: a worktree can be deleted by `lgtm`, and
# a launchd job pointed into a deleted directory fails silently, forever.
set -uo pipefail   # NOT -e: inspect the failure, don't die on it
source "${0:A:h}/../lib/common.sh"

job="${0:A:h:t}"
repo=__REPO__

# launchd hands us a minimal PATH; spell out where uv/git/etc live.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"

# Asserted, not sourced-if-present: ~/.cache is exactly the kind of directory that
# gets cleared, and a job running without its frozen env can exit 0 while doing the
# wrong thing (writing a different cache, hitting a different database) forever.
env_file="$HOME/.cache/jobs/${job}.env"
if [[ ! -f "$env_file" ]]; then
  log "$job: FATAL — frozen env $env_file is missing"
  notify "__JOB__ failed" "frozen env missing — run: make start JOB=$job"
  exit 1
fi
source "$env_file"

log "$job: starting"
cd "$repo" || { log "$job: FATAL — $repo is gone"; notify "__JOB__ failed" "$repo is gone"; exit 1; }

# Wall-clock bound + hold sleep off for the duration. A hang is the one failure a job
# cannot report — it never exits, so it never notifies. `timeout` converts it into an
# ordinary exit 124 down the failure branch. `-s` is the load-bearing half of
# caffeinate: launchd runs this during a DarkWake, and `-i` alone does not hold that
# window open. Size the budget well above the worst legitimate run.
caffeinate -is timeout __TIMEOUT__ __COMMAND__
# NOT `status` — zsh reserves it as a read-only alias for $?, so assigning it aborts
# the script between the command and the branch below, silently disabling every
# notification this job could ever send.
exit_code=$?

if (( exit_code == 0 )); then
  log "$job: done"
else
  detail="$(tail -n 1 "$HOME/.cache/jobs/${job}.err" 2>/dev/null)"
  log "$job: FAILED (exit $exit_code)"
  notify "__JOB__ failed" "exit $exit_code — ${detail:-see make tail JOB=$job}"
fi

exit $exit_code
