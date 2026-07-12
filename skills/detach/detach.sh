#!/usr/bin/env bash
# detach — open a new interactive agent-CLI window seeded with a task.
#
# /detach spins off a parallel interactive session in its own terminal window,
# pre-seeded with a task. The calling agent hands the work off to that window; it never
# drives the session itself. Because the session is a normal interactive one, it persists
# on disk and shows up in the engine's own resume flow natively — no headless run, no
# log-rewriting hacks, no single-writer footgun.
#
# Engine-agnostic: works with either `claude` (Claude Code) or `opencode` (OpenCode) via
# --engine. Claude Code titles the session for /resume (`claude --name`); OpenCode has no
# interactive session title, so it is resumed by id/`--continue` instead — see NOTE below.
#
# Created 2026-06-10. Rewritten 2026-06-25 (option-1 redesign). 2026-07-07: engine-agnostic.
# Companion: ./SKILL.md
set -euo pipefail

LAUNCH_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/detach"
mkdir -p "$LAUNCH_DIR"

die() { echo "detach: $*" >&2; exit 1; }
command -v osascript >/dev/null || die "osascript not found (detach needs macOS)"

# Pick the default engine: honour $DETACH_ENGINE, else the first CLI on PATH (claude wins).
_default_engine() {
  case "${DETACH_ENGINE:-}" in claude|opencode) echo "$DETACH_ENGINE"; return;; esac
  if command -v claude >/dev/null; then echo claude
  elif command -v opencode >/dev/null; then echo opencode
  else echo claude; fi
}

# Open a new terminal tab that cd's to `dir` and runs `cmd`. The command is written to a
# launcher script so the terminal only needs a clean path — this avoids nested-quoting hell
# between the launcher, AppleScript, and the shell the terminal spawns. The tab *sources*
# the launcher so the `cd` lands on the interactive shell itself: the agent starts in `dir`,
# and quitting it drops you to a prompt still in `dir` (not back in ~). iTerm gets a real
# tab; Terminal.app falls back to a new window (tabs there need flaky System Events keystrokes).
#
# Deliberately no `activate`: the tab opens in the background so it never steals focus. If
# the human is typing in another tab/app when this fires, an `activate` would yank focus and
# their keystrokes could land in the new session and corrupt the seeded command.
_open_window() {  # dir cmd
  local dir="$1" cmd="$2"
  find "$LAUNCH_DIR" -name 'launch-*.sh' -mmin +60 -delete 2>/dev/null || true
  local launcher="$LAUNCH_DIR/launch-$$.sh"
  printf 'cd %q || return 1\n%s\n' "$dir" "$cmd" > "$launcher"
  case "${TERM_PROGRAM:-}" in
    iTerm.app)
      osascript - "$launcher" <<'OSA'
on run argv
  tell application "iTerm"
    if (count of windows) = 0 then
      create window with default profile
    else
      tell current window to create tab with default profile
    end if
    tell current session of current window to write text ("source " & quoted form of (item 1 of argv))
  end tell
end run
OSA
      ;;
    *)
      osascript - "$launcher" <<'OSA'
on run argv
  tell application "Terminal"
    do script ("source " & quoted form of (item 1 of argv))
  end tell
end run
OSA
      ;;
  esac
}

# Build the interactive command for the chosen engine. --label seeds a human title where the
# engine supports one; --model is passed through verbatim (Claude: "sonnet"; OpenCode:
# "provider/model"), so the caller supplies the right form for the engine.
_engine_cmd() {  # engine label model prompt
  local engine="$1" label="$2" model="$3" prompt="$4" cmd
  case "$engine" in
    claude)
      cmd="$(printf 'claude --name %q' "[detached] $label")"
      [ -n "$model" ] && cmd+="$(printf ' --model %q' "$model")"
      cmd+="$(printf ' %q' "$prompt")"
      ;;
    opencode)
      # NOTE: OpenCode's interactive TUI has no session-title flag (--title is `run`-only),
      # so <label> cannot appear in its resume picker; resume via `opencode --continue` or
      # `opencode --session <id>` instead. --prompt seeds the first message.
      cmd="$(printf 'opencode --prompt %q' "$prompt")"
      [ -n "$model" ] && cmd+="$(printf ' --model %q' "$model")"
      ;;
    *) die "unknown engine '$engine' (want: claude|opencode)";;
  esac
  printf '%s' "$cmd"
}

sub_new() {
  local cwd="$PWD" model="" label="" engine="" rest=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --cwd)    cwd="$2"; shift 2;;
      --model)  model="$2"; shift 2;;
      --label)  label="$2"; shift 2;;
      --engine) engine="$2"; shift 2;;
      --) shift; rest+=("$@"); break;;
      -*) die "new: unknown flag $1";;
      *)  rest+=("$1"); shift;;
    esac
  done
  [ "${#rest[@]}" -gt 0 ] || die "new: missing prompt"
  [ -n "$label" ] || die "new: --label is required (it titles the session where supported)"
  [ -d "$cwd" ] || die "new: --cwd not a directory: $cwd"
  [ -n "$engine" ] || engine="$(_default_engine)"
  command -v "$engine" >/dev/null || die "$engine CLI not on PATH"

  local cmd; cmd="$(_engine_cmd "$engine" "$label" "$model" "${rest[*]}")"
  _open_window "$cwd" "$cmd"
  printf '— detach: opened a new %s tab — "[detached] %s"\n    cwd: %s\n' "$engine" "$label" "$cwd" >&2
  [ "$engine" = claude ] && printf '    Also listed in /resume under that name.\n' >&2 || \
    printf '    Resume it with `opencode --continue` from that dir (OpenCode has no titled resume).\n' >&2
}

cmd="${1:-}"; shift || true
case "$cmd" in
  new) sub_new "$@";;
  ""|-h|--help|help)
    cat <<'USAGE'
detach — open a new interactive agent-CLI window seeded with a task

  new <prompt...> --label "<title>" [--engine claude|opencode] [--cwd DIR] [--model M]
       Open a new terminal window running an interactive agent session (claude or opencode)
       seeded with <prompt>. --label is required (titles the session for Claude Code's
       /resume; OpenCode has no titled resume — use `opencode --continue`). --engine
       defaults to $DETACH_ENGINE, else the first of claude/opencode on PATH. --cwd defaults
       to the current dir. --model is passed through verbatim (Claude: "sonnet"; OpenCode:
       "provider/model"). The calling agent hands off to the tab; it does not drive it.
USAGE
    ;;
  *) die "unknown command '$cmd' (try: detach help)";;
esac
