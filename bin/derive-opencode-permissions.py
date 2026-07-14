#!/usr/bin/env python3
"""Derive an OpenCode permission config from Claude Code's settings.json.

settings.json is the one owned definition of what an agent may touch. OpenCode cannot read it
(verified: `opencode debug config` resolves `permission: null` with a full block present), so it is
translated here rather than copied. Emits JSON for OPENCODE_CONFIG_CONTENT, which merges onto the
user's own opencode config, so only `permission` is emitted.

Three behaviours of OpenCode, all measured against 1.17.18, make a literal translation dangerous:

  1. Rules are LAST-MATCH-WINS, appended after built-ins that already allow everything. So an
     emitted allow can only ever weaken a deny -- Claude's `Bash(git:*)` allow, landing after its
     `Bash(git push --force:*)` deny, would silently re-permit the force-push. Only denies cross.
     Exceptions (`--allow-read`) are emitted last, so they can carve one out.

  2. `**/x` does NOT match a root-level `x` (Claude, following gitignore, does). Emitting only
     `**/.env.*` left a root `.env.prod` matching nothing but the built-in allow -- that is how a
     real secret leaked on 2026-07-13. Read patterns are therefore emitted in both forms; bash
     patterns match a command string, not a path, so they get no `**/` form.

  3. The built-in `.env*` guard is `ask`, which auto-rejects headless. Claude's `ask` is likewise
     unanswerable there, so it becomes `deny`.

Claude's deny is absolute and cannot carry an exception, so `--allow-read` is inexpressible there:
Claude stays stricter on `.env*` than a reviewer that needs to see tracked templates. That is the
one divergence, and it is the safe direction.

Not a sandbox: bash stays open in both engines, so `cat .env.prod` is reachable regardless.

Created 2026-07-13.
"""

import argparse
import json
import re
import sys
from pathlib import Path

SETTINGS = Path.home() / ".claude" / "settings.json"
RULE = re.compile(r"^(?P<tool>\w+)\((?P<pattern>.*)\)$")
TOOL_KEYS = {"Read": "read", "Bash": "bash", "WebFetch": "webfetch", "Edit": "edit", "Write": "edit"}


def parse_rule(rule: str) -> tuple[str, str] | None:
    """`Read(**/.env)` -> `("read", "**/.env")`. Bare names (`WebSearch`) and MCP tools yield None."""
    match = RULE.match(rule.strip())
    if not match:
        return None
    key = TOOL_KEYS.get(match["tool"])
    return (key, match["pattern"]) if key else None


def glob_variants(pattern: str) -> list[str]:
    bare = pattern[3:] if pattern.startswith("**/") else pattern
    return list(dict.fromkeys([f"**/{bare}", bare]))


def bash_glob(pattern: str) -> str:
    """Deliberately broader than Claude's `:*`, which implies a word boundary: this also denies
    `git push --force-with-lease`. Over-denying is the safe direction."""
    return pattern[:-2] + "*" if pattern.endswith(":*") else pattern


def derive(settings: dict, deny_edits: bool, allow_reads: list[str]) -> dict:
    permissions = settings.get("permissions") or {}
    read: dict[str, str] = {}
    edit: dict[str, str] = {}
    bash: dict[str, str] = {}
    webfetch: str | None = None

    untranslatable: list[str] = []
    for rule in [*permissions.get("deny", []), *permissions.get("ask", [])]:
        parsed = parse_rule(rule)
        if not parsed:
            untranslatable.append(rule)
            continue
        key, pattern = parsed
        if key == "read":
            for glob in glob_variants(pattern):
                read[glob] = "deny"
        elif key == "edit":
            for glob in glob_variants(pattern):
                edit[glob] = "deny"
        elif key == "bash":
            bash[bash_glob(pattern)] = "deny"
        elif key == "webfetch":
            webfetch = "deny"

    for pattern in allow_reads:
        for glob in glob_variants(pattern):
            read[glob] = "allow"

    permission: dict[str, object] = {}
    # Blanket read-only subsumes the per-path edit denies; without it they must still be emitted.
    if deny_edits:
        permission["edit"] = "deny"
    elif edit:
        permission["edit"] = edit
    if read:
        permission["read"] = read
    if bash:
        permission["bash"] = bash
    if webfetch:
        permission["webfetch"] = webfetch

    denies = sum(1 for decision in read.values() if decision == "deny") + len(edit) + len(bash)
    allowed = len(permissions.get("allow", []))
    print(f"derive-opencode-permissions: carried {denies} denies; ignored {allowed} allow rules "
          f"(OpenCode defaults to allow, and an emitted allow would override a deny under "
          f"last-match-wins)", file=sys.stderr)

    # A deny that binds Claude but not the reviewer must never vanish quietly.
    if untranslatable:
        print(f"derive-opencode-permissions: WARNING — {len(untranslatable)} deny/ask rule(s) have "
              f"no OpenCode equivalent and are NOT enforced on the reviewer: "
              f"{', '.join(untranslatable)}", file=sys.stderr)

    return {"$schema": "https://opencode.ai/config.json", "permission": permission}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--settings", type=Path, default=SETTINGS)
    parser.add_argument("--deny-edits", action="store_true",
                        help="enforce read-only (opencode's `edit` gates write/edit/patch)")
    parser.add_argument("--allow-read", action="append", default=[], metavar="GLOB",
                        help="carve a read exception out of the derived denies; repeatable. "
                             "Inexpressible in Claude, so justify it at the call site.")
    args = parser.parse_args()

    # An empty permission block is a wide-open agent, so never emit one.
    if not args.settings.is_file():
        sys.exit(f"derive-opencode-permissions: no settings file at {args.settings}")
    try:
        settings = json.loads(args.settings.read_text())
    except json.JSONDecodeError as exc:
        sys.exit(f"derive-opencode-permissions: {args.settings} is not valid JSON: {exc}")

    config = derive(settings, args.deny_edits, args.allow_read)
    if not config["permission"]:
        sys.exit(f"derive-opencode-permissions: {args.settings} yielded no permission rules")
    print(json.dumps(config))


if __name__ == "__main__":
    main()
