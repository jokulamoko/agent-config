---
name: detach
description: Write a handoff doc, then spin off a parallel interactive agent session (Claude Code or OpenCode) in a new terminal tab seeded with it. Use to hand a chunk of work to a fresh tab the human drives.
---

# detach

`/detach` opens a **new terminal tab running a fresh interactive agent session** (`claude`
or `opencode`), pre-seeded with a task and labelled `[detached] <label>`. You seed it and
hand it off — the tab is the single driver of that session; you do not drive it yourself.

## Always handoff first

Every `/detach` begins by writing a handoff doc, then seeds the new session with it — so the
work continues in a durable, human-takeable stream.

1. **Write the handoff.** Follow `/handoff` to produce the doc and note its path. Done when a
   fresh agent could resume from the doc alone.
2. **Detach, seeded with the doc.** Run the engine (below) with a task that reads that doc and
   takes its next action — pass the path in the prompt, and `--label` from the handoff's focus.

Then hand the resume command back to the user.

## Detaching a `/leaf`

Seed the skill; don't pre-build its world. Never create the worktree, branch, or DB branch
yourself — `--cwd` the base repo and seed the prompt with `/leaf <task>` plus the handoff path.
The detached agent creates the worktree and switches itself into it.

A session is resumable only from the dir it was launched in, so one launched inside the worktree
loses its resume entry to `lgtm` — which deletes that worktree. And `/leaf` owns its own setup:
doing half of it here just forces the agent to detect and skip steps.

Because it's an ordinary interactive session (not a headless run), it:

1. **Opens immediately** in its own tab, with the task already seeded as the first prompt.
2. **Persists on disk** and survives this conversation.
3. **Is resumable natively** — Claude Code shows it in `/resume` titled `[detached] <label>`
   (set via `claude --name`); OpenCode has no titled resume, so resume it with
   `opencode --continue` from the same dir. No log-rewriting hacks, no promotion step.

The engine is `./detach.sh`.

## Usage

```
~/.claude/skills/detach/detach.sh new "<task prompt>" --label "<short title>" \
    [--engine claude|opencode] [--cwd DIR] [--model M]
```

This writes a launcher and opens a new tab (iTerm; Terminal.app falls back to a new window)
running the chosen engine seeded with the prompt:
- `claude`   → `claude --name "[detached] <label>" [--model M] "<task prompt>"`
- `opencode` → `opencode --prompt "<task prompt>" [--model M]`

- **`--label` is required.** It titles the session where the engine supports one (Claude
  Code's prompt box and `/resume`, shown as `[detached] <label>`). Make it short and
  specific — what this stream *is* at a glance: `--label "migrate auth to OAuth"`, not
  `--label "task"`.
- **`--engine`** picks the CLI. Defaults to `$DETACH_ENGINE`, else the first of
  `claude`/`opencode` found on PATH.
- **`--cwd`** defaults to the current dir; the session opens in that dir exactly as given.
  Note the consequence: a resume picker only lists a session from the dir it was launched in,
  so a session started inside a `/leaf` worktree is resumable only from that worktree — and
  disappears once `lgtm` deletes it. Launch from where you want it to live (and resume from):
  for a leaf, that is the base repo, and the detached agent creates the worktree itself
  (see *Detaching a `/leaf`*).
- **`--model`** overrides the model, passed through verbatim (Claude: `sonnet`; OpenCode:
  `provider/model`).

After it runs, tell the human a new window is open and how to resume it if they close it
(`/resume` on Claude Code; `opencode --continue` on OpenCode).

## Design notes

- **It's interactive, not headless.** The whole point is that a human drives the new window.
  There is no agent-driven `send`/`--bg`/`watch` and no single-writer footgun, because the
  calling agent never writes to the session — only the window does.
- **No `.jsonl` hacks.** A native interactive session is titled/tracked by the engine itself,
  so it shows up in the engine's own resume flow out of the box.

## Permissions

The new window is a fresh agent process: it inherits that engine's own config (Claude Code:
`settings.json` `defaultMode` + `allow`/`deny`), but not this session's runtime grants. To
grant a tool the default mode won't, widen the engine's allow-list (scoped) rather than
bypassing the rails.

## Ergonomics

Put it on PATH: `ln -s ~/.claude/skills/detach/detach.sh ~/.local/bin/detach`, then
`detach new "..." --label "..."`.

## Limits

1. **macOS only** — uses `osascript` to open iTerm/Terminal. Other platforms would need a
   different `_open_window`.
2. Opening uses the iTerm/Terminal AppleScript path; an unusual terminal falls back to
   Terminal.app.
3. **OpenCode has no titled resume** — its interactive TUI ignores session titles (only the
   headless `run` takes `--title`), so `<label>` won't appear in an OpenCode resume picker;
   use `opencode --continue`.
