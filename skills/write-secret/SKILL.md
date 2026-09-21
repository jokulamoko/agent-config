---
name: write-secret
description: Copy keys between .env files, or stub them into .env.example, without ever seeing their values. Use whenever a secret or env var needs moving between .env files ("copy the API key into the worktree's .env", "add FOO to .env.example").
---

# write-secret

You are **blind** to secret values. The script moves them; you only ever handle key names.

```
~/.claude/skills/write-secret/write-secret.py <KEY[,KEY...]> --target <path> [--source <path>] [--overwrite]
~/.claude/skills/write-secret/write-secret.py <KEY[,KEY...]> --source <path> --check
```

- **Real target** (`.env`, `.env.local`, ...): `--source` required. Each key's value is copied
  verbatim from source; absent keys are appended as a block after a blank line, equal ones left
  alone. A key whose value
  differs is refused unless `--overwrite` — pass it only when the user asked to replace it.
- **Example target** (any `*.example`): no `--source`. Each key is written as `KEY=`; an existing
  entry is left untouched.
- **Check** (`--check`): writes nothing. Prints `present|empty|missing|duplicated <KEY> <source>`
  per key; exit 1 unless all are present. `empty` covers `KEY=`, `KEY=""` and `KEY= # comment` —
  `present` means a real value. This is how you learn whether a file holds a key.

Idempotent and all-or-nothing — re-run freely; any refusal leaves the target unchanged. Stdout is
one `added|updated|unchanged <KEY> <target>` line per key. Exit 1 is a refusal, one stderr line per
failing key (missing, empty, duplicated, multi-line or differing) — relay them all to the user in
one go; they fix the file, not you.

## Staying blind

- Never `cat`, `grep`, `sed`, `head`, `Read` or otherwise open a real `.env` file — not to check
  a key exists, not to verify the copy. The script's output is the verification.
- Never pass a value on a command line, or echo, export or `source` one.
- To learn whether a file holds a key, use `--check`.
