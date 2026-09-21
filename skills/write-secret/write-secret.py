#!/usr/bin/env python3
"""write-secret — copy .env keys between files without any value reaching stdout/stderr.

    write-secret.py <KEY[,KEY...]> --target <path> [--source <path>] [--overwrite]
    write-secret.py <KEY[,KEY...]> --source <path> --check

    Copy each KEY's value from --source into --target. Idempotent: absent keys are appended as a
    block after a blank line, an equal one is left alone, and a differing one is refused unless
    --overwrite, which replaces it in place.

    A target named *.example (e.g. .env.example) takes no --source: each KEY is written as an
    empty placeholder `KEY=`, and an existing entry is left untouched so a documented default
    survives.

    --check writes nothing: it reports each KEY in --source as present, empty, missing or duplicated, and
    exits 1 unless all are present.

All or nothing: every key is resolved before the target is written, so any refusal leaves the
target exactly as it was — and every key's refusal is reported, not just the first.

Output is one line per key on stdout — `<outcome> <KEY> <file>` — and nothing
else. Every error names the file and key, never the line, because the line holds the value.

The value's raw right-hand side is copied verbatim (quotes, escapes, inline comments included),
so there is no quoting round-trip to get wrong. Multi-line quoted values are refused rather
than half-copied. Writes are atomic and keep the target's mode; a new target is created 0600.

Exit codes: 0 ok, 1 refused (missing key, differing value without --overwrite, ...), 2 bad usage.
"""

import argparse
import os
import re
import sys
import tempfile
from pathlib import Path

KEY_PATTERN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
# Right-hand side of `KEY=`, `KEY=""`, `KEY= # todo`. `KEY=#x` is a value: a comment needs whitespace.
BLANK_VALUE = re.compile(r"""(?:\s*(?:""|''))?(?:\s+#.*)?\s*""")


class Refusal(Exception):
    pass


def assignment(key: str) -> re.Pattern[str]:
    # Optional `export `, KEY, `=`; group 1 is everything up to and including the `=`.
    return re.compile(rf"^(\s*(?:export\s+)?{re.escape(key)}\s*=)")


class EnvFile:
    def __init__(self, path: Path) -> None:
        self.path = path
        self._lines = path.read_text().splitlines(keepends=True) if path.exists() else []
        self._has_appended = False

    @property
    def is_example(self) -> bool:
        return self.path.name.endswith(".example")

    def _index(self, key: str) -> int | None:
        pattern = assignment(key)
        indices = [i for i, line in enumerate(self._lines) if pattern.match(line)]
        if len(indices) > 1:
            raise Refusal(f"{key} is assigned {len(indices)} times in {self.path}; dedupe it by hand")
        return indices[0] if indices else None

    def has(self, key: str) -> bool:
        return self._index(key) is not None

    def get_presence(self, key: str) -> str:
        try:
            index = self._index(key)
        except Refusal:
            return "duplicated"
        if index is None:
            return "missing"
        return "empty" if BLANK_VALUE.fullmatch(self._get_right_side(index, key)) else "present"

    def _get_right_side(self, index: int, key: str) -> str:
        return assignment(key).sub("", self._lines[index].rstrip("\r\n"), count=1)

    def get_raw_value(self, key: str) -> str:
        index = self._index(key)
        if index is None:
            raise Refusal(f"{key} not found in {self.path}")
        right_side = self._get_right_side(index, key)
        if BLANK_VALUE.fullmatch(right_side):
            raise Refusal(f"{key} is empty in {self.path}")
        raw = right_side.strip()
        quote = raw[0]
        if quote in "\"'" and not re.match(rf"{quote}(?:\\.|[^{quote}\\])*{quote}", raw):
            raise Refusal(f"{key} in {self.path} is a multi-line or unterminated quoted value")
        return raw

    def put(self, key: str, raw_value: str, overwrite: bool = False) -> str:
        index = self._index(key)
        if index is None:
            if self._lines and not self._lines[-1].endswith("\n"):
                self._lines[-1] += "\n"
            if self._lines and self._lines[-1].strip() and not self._has_appended:
                self._lines.append("\n")
            self._has_appended = True
            self._lines.append(f"{key}={raw_value}\n")
            return "added"
        line = self._lines[index]
        new_line = f"{assignment(key).match(line).group(1)}{raw_value}\n"
        if line.rstrip("\r\n") == new_line.rstrip("\n"):
            return "unchanged"
        if not overwrite:
            raise Refusal(f"{key} already differs in {self.path}; pass --overwrite to replace it")
        self._lines[index] = new_line
        return "updated"

    def save(self) -> None:
        mode = self.path.stat().st_mode & 0o777 if self.path.exists() else 0o600
        self.path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=self.path.parent, prefix=f".{self.path.name}.")
        try:
            with os.fdopen(fd, "w") as f:
                f.writelines(self._lines)
            os.chmod(tmp, mode)
            os.replace(tmp, self.path)
        except BaseException:
            os.unlink(tmp)
            raise


def sync(
    keys: list[str], target: EnvFile, source: EnvFile | None, overwrite: bool
) -> list[tuple[str, str]]:
    if target.is_example:
        if source is not None:
            raise Refusal(f"{target.path} is an example file; it takes no --source")
        write = lambda key: "unchanged" if target.has(key) else target.put(key, "")
    else:
        if source is None:
            raise Refusal(f"{target.path} is not an example file; --source is required")
        if source.path.resolve() == target.path.resolve():
            raise Refusal("--source and --target are the same file")
        write = lambda key: target.put(key, source.get_raw_value(key), overwrite)
    outcomes, failures = [], []
    for key in keys:
        try:
            outcomes.append((key, write(key)))
        except Refusal as refusal:
            failures.append(str(refusal))
    if failures:
        raise Refusal("\n".join(failures))
    if any(outcome != "unchanged" for _, outcome in outcomes):
        target.save()
    return outcomes


def main() -> int:
    parser = argparse.ArgumentParser(description="Copy .env keys without revealing their values.")
    parser.add_argument("keys", help="one key, or several comma-separated")
    parser.add_argument("--target", type=Path)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--overwrite", action="store_true", help="replace keys whose value differs")
    parser.add_argument("--check", action="store_true", help="only report whether keys are in --source")
    args = parser.parse_args()
    if args.check and (args.source is None or args.target is not None or args.overwrite):
        parser.error("--check takes --source only")
    if not args.check and args.target is None:
        parser.error("--target is required")

    keys = [key.strip() for key in args.keys.split(",") if key.strip()]
    invalid = [key for key in keys if not KEY_PATTERN.fullmatch(key)]
    if not keys or invalid:
        print(f"write-secret: invalid keys {invalid or args.keys!r}", file=sys.stderr)
        return 2
    if len(set(keys)) != len(keys):
        print("write-secret: a key is listed twice", file=sys.stderr)
        return 2
    if args.source is not None and not args.source.is_file():
        print(f"write-secret: source {args.source} does not exist", file=sys.stderr)
        return 2

    if args.check:
        source = EnvFile(args.source)
        presences = [(key, source.get_presence(key)) for key in keys]
        for key, presence in presences:
            print(f"{presence} {key} {args.source}")
        return 0 if all(presence == "present" for _, presence in presences) else 1

    try:
        source = EnvFile(args.source) if args.source is not None else None
        outcomes = sync(keys, EnvFile(args.target), source, args.overwrite)
    except Refusal as refusal:
        for failure in str(refusal).splitlines():
            print(f"write-secret: {failure}", file=sys.stderr)
        return 1
    for key, outcome in outcomes:
        print(f"{outcome} {key} {args.target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
