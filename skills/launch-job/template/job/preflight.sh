#!/usr/bin/env zsh
# __JOB__ — install-time preflight, run by `jobctl start` in YOUR terminal before the
# agent is loaded. A missing or revoked secret fails loudly here instead of silently
# FATAL-ing every tick.
#
# Like run.sh, this is only the wrapper: the actual check belongs to the owning
# project, which knows what its config is. Exercise the credential (one live call),
# don't just assert it is present — presence is not usability.
set -euo pipefail
source "${0:A:h}/../lib/common.sh"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"

# The same frozen env run.sh sources each tick, so the check runs under real conditions.
env_file="$HOME/.cache/jobs/${0:A:h:t}.env"
[[ -f "$env_file" ]] && source "$env_file"

log "__JOB__: preflight"
cd __REPO__
exec __PREFLIGHT_COMMAND__
