# Shared helpers for job run.sh scripts. Source it as:
#   source "${0:A:h}/../lib/common.sh"
#
# launchd captures a job's stdout/stderr into ~/.cache/jobs/<job>.{out,err},
# so just printing is enough — no logging framework needed. This only adds a
# UTC timestamp so the logs are greppable across jobs.

log() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

# Raise a macOS notification: notify <title> <message>.
#
# For the failure of an unattended job. A job that only writes its error to
# ~/.cache/jobs/<job>.err is indistinguishable from one that never fired, because
# both look like silence — and the rarer the schedule, the longer that silence can
# go unnoticed. A daily job that dies has six days to be missed before you would
# even expect it again, so a failure has to *push*.
#
# Text is passed as argv, never interpolated into the AppleScript: an error message
# is the least predictable string in the system and one stray quote would turn a
# failed job into a failed notification about a failed job.
#
# Best-effort by contract. Notification delivery is subject to macOS permissions
# and Focus, so it can be suppressed for reasons that have nothing to do with the
# job — it must never change the job's own exit status. The log stays the record;
# this is only the nudge to go read it.
notify() {
  osascript - "$1" "$2" >/dev/null 2>&1 <<'APPLESCRIPT' || log "notify: osascript failed (continuing)"
on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run
APPLESCRIPT
}
