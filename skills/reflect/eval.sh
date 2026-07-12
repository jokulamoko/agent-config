#!/usr/bin/env bash
# reflect eval — run a fresh reviewer on an INDEPENDENT engine, headless, and
# print its review to stdout for the caller to proxy.
#
# This is the inverse of detach.sh: detach opens an interactive tab and hands off
# to a human; eval runs headless and captures the output back into the calling
# session. /reflect uses it when it wants a judge that is genuinely different
# weights from the model that did the work — not a same-model sub-agent.
#
# Read-only is structural for the file-editing tools: opencode's `edit` permission
# gates write/edit/patch (all check it — there is no separate key), so
# `permission.edit=deny` blocks them outright. It is NOT a hermetic sandbox — bash
# stays open (the reviewer must run `git diff` and any verification), so a mandate,
# not a cage, holds bash read-only. This is the same posture as /reflect's
# Explore/general-purpose sub-agents, which also carry Bash and honour the mandate.
#
# Engine-agnostic by seam, not by speculation: only `opencode` is implemented
# (the Claude path is already covered by /reflect's Agent-tool sub-agent). Adding
# an engine is a new case branch.
#
# Created 2026-07-08. Companion: ./SKILL.md
set -euo pipefail

die() { echo "reflect-eval: $*" >&2; exit 1; }

run_eval() {
  local engine="${REFLECT_ENGINE:-opencode}" model="${REFLECT_MODEL:-}" cwd="$PWD" prompt_file=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --engine)      engine="$2"; shift 2;;
      --model)       model="$2"; shift 2;;
      --cwd)         cwd="$2"; shift 2;;
      --prompt-file) prompt_file="$2"; shift 2;;
      -*) die "unknown flag $1";;
      *)  die "unexpected argument $1";;
    esac
  done
  [ -d "$cwd" ] || die "--cwd not a directory: $cwd"

  local prompt
  if [ -n "$prompt_file" ]; then
    [ -f "$prompt_file" ] || die "--prompt-file not found: $prompt_file"
    prompt="$(cat "$prompt_file")"
  else
    prompt="$(cat)"  # from stdin
  fi
  [ -n "$prompt" ] || die "empty prompt (pass --prompt-file or pipe on stdin)"

  case "$engine" in
    opencode)
      command -v opencode >/dev/null || die "opencode not on PATH"
      # Merge a read-only override onto the user's own opencode config (provider,
      # model, everything else survive); edit:deny is the enforced invariant.
      OPENCODE_CONFIG_CONTENT='{"$schema":"https://opencode.ai/config.json","permission":{"edit":"deny"}}' \
        opencode run "$prompt" --dir "$cwd" ${model:+--model "$model"}
      ;;
    *) die "unsupported engine '$engine' (implemented: opencode)";;
  esac
}

run_eval "$@"
