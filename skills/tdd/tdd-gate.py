#!/usr/bin/env python3
"""Mechanical gate for the tdd skill.

    tdd-gate.py red <test-path>...   new behaviour: every test must FAIL, then its node ID is pinned
    tdd-gate.py pin <test-path>...   refactor: every characterisation test must PASS, then pinned
    tdd-gate.py green                re-run the pinned node IDs and require every one of them to pass
    tdd-gate.py stub on|off          suspend the guard hook for a bare signature stub, then restore it

`red` refuses unless every collected test failed: an ERROR is broken rather than red, and a PASS
means the behaviour was never missing. `pin` is the refactor twin — behaviour is already there, so
the tests must be green before the change and green after. `green` compares against the pinned set,
so a test deleted or renamed on the way to green is a failure, not a silence. `--add` unions into
the existing pins rather than replacing them, so a bug found mid-branch gets its own red cycle
without discarding the anchor's.

Both the pinfile and the stub flag live under the worktree's git directory: never committed, never
gitignored, never replayed by a rebase, and removed with the worktree they belong to.
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

OK, GATE_FAILED, BAD_USAGE = 0, 1, 2


def repo_root() -> Path:
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True
    )
    if out.returncode != 0:
        sys.exit(fail("not inside a git repository"))
    return Path(out.stdout.strip())


def branch_name(root: Path) -> str:
    out = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--abbrev-ref", "HEAD"],
        capture_output=True,
        text=True,
    )
    return out.stdout.strip() or "detached"


def git_path(root: Path, relative: str) -> Path:
    """Resolve a path inside this worktree's git directory."""
    out = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--git-path", relative],
        capture_output=True,
        text=True,
    )
    return root / out.stdout.strip()


def pinfile_for(root: Path) -> Path:
    return git_path(root, f"tdd/{branch_name(root).replace('/', '-')}.json")


def stub_flag_for(root: Path) -> Path:
    return git_path(root, "tdd-off")


def resolve_runner(root: Path) -> list[str]:
    runner = os.environ.get("TDD_RUNNER")
    if runner:
        return runner.split()
    return ["uv", "run", "pytest"] if (root / "uv.lock").exists() else ["pytest"]


def run_pytest(root: Path, runner: list[str], targets: list[str]) -> dict[str, str]:
    """Run the targets and return {node_id: outcome}."""
    with tempfile.TemporaryDirectory() as tmp:
        report = Path(tmp) / "junit.xml"
        subprocess.run(
            # xunit1 is the only family that emits the file attribute node IDs are rebuilt from
            [*runner, "-q", "--tb=no", "-o", "junit_family=xunit1", f"--junitxml={report}", *targets],
            cwd=root,
            check=False,
        )
        if not report.exists():
            sys.exit(fail(f"{' '.join(runner)} produced no JUnit report — is pytest installed?"))
        return parse_report(report)


def collect_nodes(root: Path, runner: list[str], targets: list[str]) -> set[str]:
    """Node IDs pytest can currently resolve under the targets."""
    out = subprocess.run(
        [*runner, "--collect-only", "-q", *targets], cwd=root, capture_output=True, text=True
    )
    return {line.strip() for line in out.stdout.splitlines() if "::" in line}


def parse_report(report: Path) -> dict[str, str]:
    outcomes: dict[str, str] = {}
    for case in ET.parse(report).getroot().iter("testcase"):
        outcomes[node_id(case)] = case_outcome(case)
    return outcomes


def node_id(case: ET.Element) -> str:
    """Rebuild pytest's node ID from JUnit's file/classname/name attributes."""
    classname = case.get("classname") or ""
    path = case.get("file") or classname.replace(".", "/") + ".py"
    name = case.get("name") or ""
    stem = Path(path).stem
    parts = classname.split(".")
    nesting = parts[parts.index(stem) + 1 :] if stem in parts else []
    return "::".join([path, *nesting, name])


def case_outcome(case: ET.Element) -> str:
    for tag, outcome in (("error", "error"), ("failure", "failed"), ("skipped", "skipped")):
        if case.find(tag) is not None:
            return outcome
    return "passed"


def fail(message: str, *nodes: str) -> int:
    print(f"tdd-gate: {message}", file=sys.stderr)
    for node in nodes:
        print(f"  {node}", file=sys.stderr)
    return GATE_FAILED


WANTED = {"red": "failed", "pin": "passed"}
UNWANTED = {"red": "passed", "pin": "failed"}
WRONG_OUTCOME = {
    "red": (
        "NOT RED — these already pass. On a bug fix that means the bug is not reproduced, so the "
        "model of the failure is wrong; on a feature it means the assertion is tautological. "
        "Re-investigate rather than proceed."
    ),
    "pin": (
        "NOT GREEN — a characterisation test must describe behaviour as it is today. A failure "
        "means either the description is wrong, or you have found a real bug: fix that under `red` "
        "first, and refactor on a green suite."
    ),
}


def existing_nodes(pinfile: Path) -> list[str]:
    return json.loads(pinfile.read_text())["nodes"] if pinfile.exists() else []


def write_pinfile(pinfile: Path, root: Path, mode: str, nodes: list[str]) -> None:
    pinfile.parent.mkdir(parents=True, exist_ok=True)
    pinfile.write_text(
        json.dumps(
            {
                "branch": branch_name(root),
                "mode": mode,
                "runner": resolve_runner(root),
                "nodes": nodes,
            },
            indent=2,
        )
        + "\n"
    )


def gate_start(mode: str, targets: list[str], add: bool) -> int:
    root = repo_root()
    if stub_flag_for(root).exists():
        return fail("refusing while the stub guard is open — run `tdd-gate.py stub off`, then re-run")

    outcomes = run_pytest(root, resolve_runner(root), targets)
    if not outcomes:
        return fail(f"no tests collected under: {' '.join(targets)}")

    by_outcome: dict[str, list[str]] = {}
    for node, outcome in sorted(outcomes.items()):
        by_outcome.setdefault(outcome, []).append(node)

    if broken := by_outcome.get("error"):
        return fail(
            "BROKEN — these errored before reaching an assertion (import, collection or fixture). "
            "Fix and re-run; an error proves nothing either way.",
            *broken,
        )
    if skipped := by_outcome.get("skipped"):
        return fail("SKIPPED tests pin nothing — unskip or delete them.", *skipped)

    if wrong := by_outcome.get(UNWANTED[mode]):
        return fail(WRONG_OUTCOME[mode], *wrong)

    proven = by_outcome[WANTED[mode]]
    pinfile = pinfile_for(root)
    kept = existing_nodes(pinfile) if add else []
    pinned = sorted(set(proven) | set(kept))
    write_pinfile(pinfile, root, mode, pinned)

    print(f"tdd-gate: {mode} — {len(proven)} test(s) proven, {len(pinned)} pinned.")
    for node in proven:
        print(f"  {node}")
    if kept:
        print(f"  (plus {len(kept)} already pinned on this branch)")
    print("Commit these tests before touching implementation code.")
    return OK


def gate_green() -> int:
    root = repo_root()
    pinfile = pinfile_for(root)
    if not pinfile.exists():
        return fail("nothing pinned on this branch — run `tdd-gate.py red` first")

    pinned = existing_nodes(pinfile)
    runner = resolve_runner(root)

    # Diff against a collect-only pass first: an unresolvable node ID aborts the whole run as a
    # usage error, which would otherwise surface as an unhelpful "nothing ran".
    present = collect_nodes(root, runner, sorted({node.split("::")[0] for node in pinned}))
    if vanished := [node for node in pinned if node not in present]:
        return fail(
            "VANISHED — pinned tests no longer exist. Deleting or renaming a test to reach green "
            "is not reaching green. Restore them.",
            *vanished,
        )

    outcomes = run_pytest(root, runner, pinned)
    if not outcomes:
        return fail("the green run produced no results at all — the runner errored before testing")
    if still_red := [node for node in pinned if outcomes.get(node) != "passed"]:
        return fail("NOT GREEN — pinned tests still failing.", *still_red)

    print(f"tdd-gate: green — all {len(pinned)} pinned test(s) pass.")
    return OK


def gate_stub(state: str) -> int:
    flag = stub_flag_for(repo_root())
    if state == "on":
        flag.parent.mkdir(parents=True, exist_ok=True)
        flag.touch()
        print("tdd-gate: guard open for signature stubs — `tdd-gate.py stub off` once the stub is in.")
    else:
        flag.unlink(missing_ok=True)
        print("tdd-gate: guard restored.")
    return OK


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="mode", required=True)
    for mode, help_text in (
        ("red", "new behaviour: prove the tests fail for the right reason"),
        ("pin", "refactor: prove the characterisation tests describe today's behaviour"),
    ):
        start = sub.add_parser(mode, help=help_text)
        start.add_argument("targets", nargs="+", help="test files or directories to run")
        start.add_argument(
            "--add",
            action="store_true",
            help="union into this branch's existing pins instead of replacing them",
        )
    sub.add_parser("green", help="require every pinned test to pass")
    stub = sub.add_parser("stub", help="suspend the guard hook for a bare signature stub")
    stub.add_argument("state", choices=("on", "off"))

    args = parser.parse_args()
    if args.mode == "green":
        return gate_green()
    if args.mode == "stub":
        return gate_stub(args.state)
    return gate_start(args.mode, args.targets, args.add)


if __name__ == "__main__":
    sys.exit(main())
