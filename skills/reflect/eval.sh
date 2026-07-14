#!/usr/bin/env bash
# reflect eval — run a fresh reviewer on an INDEPENDENT engine, headless, and print its review to
# stdout for the caller to proxy. /reflect uses it for a judge of genuinely different weights.
#
# Permissions come from ./reviewer-permissions.sh. Not a sandbox: bash stays open (the reviewer must
# run git diff and verification), so a mandate, not a cage, holds it read-only.
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
      # OPENCODE_CONFIG_CONTENT merges onto the user's own opencode config, so the provider and
      # model — the whole point of a different-weights judge — survive.
      local permissions out rc
      permissions="$(bash "$(dirname "${BASH_SOURCE[0]}")/reviewer-permissions.sh")" \
        || die "could not derive reviewer permissions — refusing to run unconstrained"
      out="$(mktemp "${TMPDIR:-/tmp}/reflect-eval.XXXXXX")"
      # Suspended, or a non-zero opencode exit aborts the script before rc is captured, before the
      # guards below run, and before $out is cleaned up.
      set +e
      OPENCODE_CONFIG_CONTENT="$permissions" \
        opencode run "$prompt" --dir "$cwd" ${model:+--model "$model"} 2>&1 | tee "$out"
      rc=${PIPESTATUS[0]}
      set -e

      # opencode exits 0 even when the review never happened, so silence would reach the user as
      # "no findings" — an unobserved reflection laundering "I never ran" into "I found nothing".
      [ -s "$out" ] || { rm -f "$out"; die "the reviewer produced no output — the review did not run."; }

      # A denial is survivable, not fatal (measured: a denied reviewer completes the rest of its
      # brief), so warn and keep the review rather than binning it over an idle peek. Both denial
      # shapes must be matched — an auto-rejected built-in `ask`, and one of our own deny rules.
      # The extracted name must start with a letter: a reviewer of THIS repo reads this script, and
      # a looser pattern matched the grep expression below, quoted back in its own transcript.
      if grep -qE "auto-rejecting|rule which prevents you" "$out"; then
        {
          echo "reflect-eval: WARNING — the reviewer was DENIED at least one tool call, so the review may be PARTIAL."
          grep -o "permission requested: [a-z_][^;]*" "$out" | sort -u | sed 's/^/  denied: /'
          echo "  If a denied path is a tracked file the reviewer must see, add it via --allow-read above."
        } >&2
        # opencode folds a rejected tool call into a non-zero exit (a clean run exits 0, one denial
        # exits 1). Propagating that would have a caller bin a complete review over an idle peek at
        # a denied path. The warning above already says so. A crash with no denial still returns rc.
        rm -f "$out"
        return 0
      fi
      rm -f "$out"
      return "$rc"
      ;;
    *) die "unsupported engine '$engine' (implemented: opencode)";;
  esac
}

run_eval "$@"
