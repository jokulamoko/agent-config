#!/usr/bin/env bash
# The ONE definition of the reflect reviewer's permissions — prints OpenCode config JSON on stdout.
#
# The shared rules are derived from ~/.claude/settings.json, their only home. This script owns only
# the reviewer's two deviations, and exists so they are declared once rather than copy-pasted into
# every caller that spawns a reviewer, where they would drift apart.
#
#   --deny-edits   Read-only. opencode strips write/edit/patch from the toolset outright.
#   --allow-read   Tracked `.env.*.example` templates: placeholders the reviewer must see to judge a
#                  diff, but opencode's built-in `.env*` guard is `ask`, which auto-rejects headless.
#                  Claude cannot mirror this (its deny is absolute), so it stays STRICTER here.
#
# Created 2026-07-13. Consumers: ./eval.sh, ./prove-permissions.sh
set -euo pipefail

exec python3 "$HOME/.claude/bin/derive-opencode-permissions.py" \
  --deny-edits \
  --allow-read '**/.env.example' \
  --allow-read '**/.env.*.example'
