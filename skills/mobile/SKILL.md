---
name: mobile
description: The user is reading on a phone. Applies to this message only — be extremely brief, act autonomously, verify your own work, and never hand back anything a phone can't open. Use when the user invokes /mobile.
---

# Mobile

The user is on a phone. They have **no terminal, no browser they can point at your machine, and very little screen**. Typing back to you is slow and expensive.

**Scope: this message only.** The user switches between mobile and desktop within a single conversation. Do not carry these constraints into later turns unless `/mobile` is invoked again.

## 1. Succinctness

This is the most important rule.

- A few sentences. Lead with what happened; close with the next action.
- Give the direct answer. Detail unfolds only if asked.
- No code blocks unless the code *is* the answer. Describe what changed, don't paste it.
- No tables, no ASCII art, no deep nesting — they wrap unreadably on a narrow screen.
- No file trees, no log dumps, no full diffs. Summarise; leave the detail on disk.

## 2. Autonomy

Second most important. The user cannot babysit you.

- Make the reasonable call, state it in one line, keep going. Don't stop to ask what you can decide.
- Batch check-ins. One decision point at the end beats five along the way.
- When you must ask, use `AskUserQuestion` — a tap beats typing on a phone. Open prose questions are a last resort.
- Long jobs go to the background with a notification on completion. Never leave the user watching a spinner.
- Read their messages charitably. Dictated and typo'd input is normal; infer intent rather than asking them to restate it.

## 3. Close the loop yourself

The user cannot verify anything. So you must — the standard from `/contact` applies with no escape hatch.

- Never hand back work you haven't observed running. "This should work" is not an outcome.
- Run the thing, execute the query, drive the flow. Report what you *saw*, not what you expect.
- If you couldn't verify something, say so explicitly in one line. Don't let it pass silently.

## 4. Never dead-end a phone

- **Never** end a turn pointing at `localhost`. The user cannot open it.
- Never ask them to run a command and paste the output. You run it.
- Never ask them to paste a key, env var, or config. Find another way or ask a tappable question.
- Never block on an action they physically cannot take.
- `/code-cmd` (open a worktree in VS Code) is useless here. Don't offer it.

**Instead, to show work:**

- **Screenshot it.** Use the `browser` skill headless, then `SendUserFile` — images render inline on the phone.
- **Publish an Artifact.** Hosted on claude.ai and viewable on mobile.
- **Push the branch.** They can read a diff in the GitHub app.
