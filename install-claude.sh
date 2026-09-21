#!/usr/bin/env bash
# Link this agent-agnostic config into ~/.claude, where Claude Code reads it.
# Idempotent: safe to re-run after adding, renaming, or deleting a skill.

set -euo pipefail

AGENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SKILLS_DIR="$CLAUDE_DIR/skills"

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

[ -d "$AGENTS_DIR/skills" ] || { echo "install-claude: no skills/ in $AGENTS_DIR" >&2; exit 1; }

note() {
  if [ "$DRY_RUN" = 1 ]; then printf 'would %s\n' "$*"; else printf '%s\n' "$*"; fi
}
run() { [ "$DRY_RUN" = 1 ] || "$@"; }

link() {
  local src="$1" dest="$2"
  if [ -L "$dest" ]; then
    [ "$(readlink "$dest")" = "$src" ] && return 0
    run rm "$dest"
  elif [ -e "$dest" ]; then
    echo "install-claude: refusing to replace real path $dest — move it aside first" >&2
    exit 1
  fi
  run ln -s "$src" "$dest"
  note "link $dest -> $src"
}

run mkdir -p "$SKILLS_DIR"

for skill in "$AGENTS_DIR"/skills/*/; do
  link "${skill%/}" "$SKILLS_DIR/$(basename "$skill")"
done

link "$AGENTS_DIR/AGENTS.md" "$CLAUDE_DIR/CLAUDE.md"

# Prune links we own whose source is gone.
for dest in "$SKILLS_DIR"/*; do
  [ -L "$dest" ] || continue
  target="$(readlink "$dest")"
  case "$target" in
    "$AGENTS_DIR"/skills/*)
      [ -d "$target" ] && continue
      run rm "$dest"
      note "prune stale $dest"
      ;;
  esac
done
