#!/usr/bin/env python3
"""Pin the translation rules that keep the derived OpenCode config safe.

Every case here is a bug that actually escaped (2026-07-13) or a measured engine asymmetry that
silently re-opens secrets if it regresses. Fast and deterministic -- no network, no opencode.
The live behavioural proof (`skills/reflect/prove-permissions.sh`) is the integration counterpart.

Run: python3 ~/.claude/bin/test-derive-opencode-permissions.py
"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

GENERATOR = Path(__file__).parent / "derive-opencode-permissions.py"

SETTINGS = {
    "permissions": {
        "allow": ["Read(**)", "Bash(git:*)", "Bash(rm:*)", "WebFetch(*)"],
        "deny": ["Read(**/.env)", "Read(**/.env.*)", "Edit(**/migrations/*.sql)",
                 "Bash(git push --force:*)"],
        "ask": ["Read(**/secrets/**)"],
    }
}


def derive(settings: dict, *flags: str) -> tuple[dict, int]:
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump(settings, handle)
        path = handle.name
    result = subprocess.run([sys.executable, str(GENERATOR), "--settings", path, *flags],
                            capture_output=True, text=True)
    Path(path).unlink()
    if result.returncode != 0:
        return {}, result.returncode
    return json.loads(result.stdout)["permission"], 0


class TranslationRules(unittest.TestCase):
    def setUp(self) -> None:
        self.permission, _ = derive(SETTINGS)
        self.read = self.permission.get("read", {})
        self.bash = self.permission.get("bash", {})

    def test_catch_all_allow_is_never_emitted(self) -> None:
        """`Read(**)` translated literally beat the deny patterns and leaked a real .env."""
        for catch_all in ("**", "*", "**/*"):
            self.assertNotIn(catch_all, self.read)

    def test_read_denies_cover_root_and_nested(self) -> None:
        """OpenCode's `**/` needs >=1 directory segment, so `**/.env.*` alone misses a ROOT .env.prod.

        This gap -- not precedence -- is what actually leaked the secret.
        """
        self.assertEqual(self.read["**/.env.*"], "deny")
        self.assertEqual(self.read[".env.*"], "deny")

    def test_bash_allow_cannot_override_a_bash_deny(self) -> None:
        """Emitting `Bash(git:*)` as an allow would re-permit the force-push under last-match-wins."""
        self.assertEqual(self.bash["git push --force*"], "deny")
        self.assertNotIn("git*", self.bash)
        self.assertNotIn("rm*", self.bash)

    def test_bash_patterns_get_no_path_glob(self) -> None:
        """Bash globs match a command string, not a path. `**/git push...` is meaningless."""
        self.assertFalse([key for key in self.bash if key.startswith("**/")])

    def test_ask_becomes_deny(self) -> None:
        """A headless reviewer cannot answer a prompt, so `ask` must fail closed."""
        self.assertEqual(self.read["**/secrets/**"], "deny")
        self.assertEqual(self.read["secrets/**"], "deny")

    def test_edit_denies_are_not_silently_dropped(self) -> None:
        """Without --deny-edits these vanished entirely -- a fail-OPEN hole."""
        self.assertEqual(self.permission["edit"]["**/migrations/*.sql"], "deny")

    def test_deny_edits_subsumes_the_edit_map(self) -> None:
        permission, _ = derive(SETTINGS, "--deny-edits")
        self.assertEqual(permission["edit"], "deny")

    def test_allow_read_carves_an_exception_and_lands_last(self) -> None:
        """Last-match-wins: an exception emitted BEFORE the deny it carves out would be ignored."""
        permission, _ = derive(SETTINGS, "--allow-read", "**/.env.*.example")
        read = permission["read"]
        self.assertEqual(read[".env.*.example"], "allow")
        keys = list(read)
        self.assertGreater(keys.index(".env.*.example"), keys.index(".env.*"))

    def test_untranslatable_denies_are_reported_not_silently_dropped(self) -> None:
        """A deny with no OpenCode equivalent binds Claude but NOT the reviewer -- say so out loud."""
        settings = {"permissions": {"deny": ["Read(**/.env)", "WebSearch", "mcp__gmail__send"]}}
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(settings, handle)
            path = handle.name
        result = subprocess.run([sys.executable, str(GENERATOR), "--settings", path],
                                capture_output=True, text=True)
        Path(path).unlink()
        self.assertIn("WARNING", result.stderr)
        self.assertIn("WebSearch", result.stderr)
        self.assertIn("mcp__gmail__send", result.stderr)

    def test_fails_closed_on_unusable_settings(self) -> None:
        """A silently-empty permission block is a wide-open agent."""
        self.assertNotEqual(derive({"permissions": {"deny": [], "ask": []}})[1], 0)
        _, code = derive({}, )
        self.assertNotEqual(code, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
