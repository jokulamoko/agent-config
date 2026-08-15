#!/usr/bin/env python3
"""PreToolUse hook: on a feat/ or fix/ branch, block implementation edits until red is proven.

The gate opens when `tdd-gate.py red` pins the branch's failing node IDs. Before that, only tests,
test config and docs are writable. `tdd-gate.py stub on` suspends the gate for the signature stubs a
not-yet-existing symbol needs; the red gate refuses while that is open, so it cannot be forgotten.

Fails open — a broken guard must never block real work. Internal errors land in tdd-guard.error.log.
"""

import json
import os
import subprocess
import sys
import traceback
from pathlib import Path

ALLOW, BLOCK = 0, 2
GATED_BRANCHES = ("feat/", "fix/")
TEST_DIRS = {"tests", "test", "__tests__", "spec", ".library"}
TEST_FILES = {"conftest.py", "pyproject.toml", "pytest.ini", "setup.cfg", "tox.ini", ".gitignore"}
TEST_SUFFIXES = ("_test.py", ".test.ts", ".test.tsx", ".test.js", ".spec.ts", ".spec.js")


def is_test_relpath(relative: Path) -> bool:
    if TEST_DIRS & set(relative.parts):
        return True
    return (
        relative.name in TEST_FILES
        or relative.name.startswith("test_")
        or relative.name.endswith(TEST_SUFFIXES)
    )


def is_test_path(path: Path, root: Path) -> bool:
    try:
        relative = path.resolve().relative_to(root)
    except ValueError:
        return True  # outside the repo — not this gate's business
    return is_test_relpath(relative)


def git(root: Path, *args: str) -> list[str]:
    out = subprocess.run(
        ["git", "-C", str(root), *args], capture_output=True, text=True
    )
    return out.stdout.splitlines() if out.returncode == 0 else []


def git_path(root: Path, relative: str) -> Path:
    out = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--git-path", relative],
        capture_output=True,
        text=True,
    )
    return root / out.stdout.strip()


def base_ref(root: Path, branch: str) -> str | None:
    for candidate in ("@{upstream}", "main", "master"):
        if candidate != branch and git(root, "rev-parse", "--verify", "-q", candidate):
            return candidate
    return None


def work_in_flight(root: Path, branch: str) -> bool:
    """True when this branch already carries implementation changes.

    The gate exists to stop implementation being written before tests. Once a branch holds
    implementation — committed, or modified in the working tree — gating it only blocks a leaf that
    is already underway, so such branches are grandfathered. Untracked files deliberately do not
    count: a scratch note or a stray download is not work in flight, and counting them opened the
    gate on branches that had written nothing.
    """
    base = base_ref(root, branch)
    if base is None:
        return True  # cannot establish a base — fail open rather than block real work
    changed = git(root, "diff", "--name-only", "HEAD") + git(
        root, "diff", "--name-only", f"{base}...HEAD"
    )
    return any(not is_test_relpath(Path(path)) for path in changed)


def deny(path: Path) -> int:
    print(
        f"TDD gate: {path} is implementation code and red has not been proven on this branch.\n"
        "Write the failing tests first — invoke the `tdd` skill, then:\n"
        f"  {Path(__file__).parent / 'tdd-gate.py'} red <test-path>\n"
        "It pins the failing node IDs and opens this gate.\n"
        "For a bare signature stub only: `tdd-gate.py stub on`, land the stub, `tdd-gate.py stub "
        "off` (the red gate refuses while it is open).",
        file=sys.stderr,
    )
    return BLOCK


def main() -> int:
    payload = json.load(sys.stdin)
    if payload.get("tool_name") not in {"Write", "Edit", "NotebookEdit"}:
        return ALLOW

    target = payload.get("tool_input", {}).get("file_path")
    if not target:
        return ALLOW

    cwd = payload.get("cwd") or os.getcwd()
    found_root = subprocess.run(
        ["git", "-C", cwd, "rev-parse", "--show-toplevel"], capture_output=True, text=True
    )
    if found_root.returncode != 0:
        return ALLOW
    root = Path(found_root.stdout.strip()).resolve()

    branch = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--abbrev-ref", "HEAD"],
        capture_output=True,
        text=True,
    ).stdout.strip()
    if not branch.startswith(GATED_BRANCHES):
        return ALLOW

    if git_path(root, "tdd-off").exists():
        return ALLOW
    if git_path(root, f"tdd/{branch.replace('/', '-')}.json").exists():
        return ALLOW

    path = Path(target)
    if is_test_path(path, root):
        return ALLOW
    return ALLOW if work_in_flight(root, branch) else deny(path)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        Path(__file__).with_name("tdd-guard.error.log").write_text(traceback.format_exc())
        sys.exit(ALLOW)
