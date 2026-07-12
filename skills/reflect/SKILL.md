---
name: reflect
description: Spawn a fresh, read-only agent — with no knowledge of how the work unfolded — to judge whether the work fulfils the original intent, then act on its findings. Use after implementing a change to get an unbiased review.
---

# Reflect

Check whether the work actually did what was asked — judged by a reviewer who never saw how you got there — then act on what it finds.

The danger after a long implementation is that you grade your own homework: you remember every detour and rationalisation, so you see the work as you *intended* it, not as it *is*. Reflect breaks that by handing a clean-slate agent the destination without the journey. Reflection that stops at a report is wasted — the point is to fix what's broken, so reflect always ends in action.

## Phase 1 — Reflect

1. **Reconstruct the intent.** State, in your own words, what the user actually asked for — the goal and the constraints, not the steps you took. If `$ARGUMENTS` is given, treat it as the spec or the specific aspect to scrutinise. Pull the true intent from the original request, not from your summary of what you built.

2. **Commit outstanding work first (if on a branch/leaf/worktree).** The reviewer judges `git diff main...HEAD`, which shows *committed* changes only — anything left uncommitted is invisible to it, so it would grade an incomplete picture. If you're on a branch and not on `main`, run `git status` and commit any uncommitted changes to the branch before spawning. On `main` with no branch, skip this. (You do the committing here — the sub-agent is read-only and cannot.)

3. **Spawn one read-only reviewer — different weights by default.** A same-model judge shares your blind spots, so **by default** route the brief through `./eval.sh` — a headless judge of genuinely different weights (the independent engine, `opencode`, on its own default model), the sharper break from self-grading. Opt back to a same-model sub-agent on *this* engine (the `Explore` subagent_type, or `general-purpose` if it needs to run code to verify) via the Agent tool only when `$ARGUMENTS` or `$REFLECT_ENGINE` asks for it with `same`. `$REFLECT_ENGINE`/`$REFLECT_MODEL` override the engine and model otherwise. Give the reviewer everything it needs and nothing about the journey:
   - **The intent:** what the change is supposed to achieve and the constraints it must respect.
   - **Where to look:** the files, branch, or diff that hold the work (e.g. `git diff main...HEAD`, specific paths).
   - **Confirm the diff is whole:** instruct it to run `git status` and compare the branch against `main` (e.g. `git status`, `git diff main...HEAD --stat`) as its first step, so it reviews the full committed diff and flags any uncommitted or untracked leftovers rather than silently reviewing a partial change.
   - **Principles:** Prime the spawned agent to review the work against the programming principles set out in the root CLAUDE.md (especially simplicity, resiliency, orthogonality)
   - **The mandate:** *read-only*. It investigates and reports — it does not edit, fix, or commit anything.
   - **Do NOT** tell it your reasoning, the dead ends you hit, or why you made each choice. It must form an independent judgement from the intent and the code alone. If you explain your rationale, you've re-infected it with your own bias.
   - **Dispatch:** *independent engine (default)* → write the brief to a file under `/tmp` (e.g. `/tmp/reflect-brief.md`) and run `./eval.sh --cwd <repo> --prompt-file /tmp/reflect-brief.md`; it runs headless and prints the review to stdout — read it from there. `eval.sh` denies the `edit` permission, so file-editing tools are structurally blocked, but bash is not — the reviewer holds itself read-only by mandate, exactly as the Explore/general-purpose sub-agents do. *Same-model (`same`)* → spawn via the Agent tool; its report returns to you.

4. **Aim the agent at intent, not lint.** It should answer: Was the actual goal met? Were boundary cases handled? Does it solve the problem or just patch a symptom? Does it contradict any stated constraint? Surface-level style nits are secondary to "did this do what was asked."

5. **Proxy the findings into the chat.** Relay the agent's findings to the user faithfully — the agent's report is returned to you, not shown to them. Don't launder it: report disagreements and weak spots as the agent stated them. Separate the agent's findings from your own commentary if you add any.

## Phase 2 — Act

6. **Triage every finding.** For each one, decide: fix it, or consciously reject it. The reviewer was unbiased but not omniscient — it lacked your context, so some findings will be wrong or out of scope. Don't reflexively obey, and don't reflexively dismiss. Judge each on merit against the original intent.

7. **Act on what survives triage.** Make the changes. Hold to the same bar as the original work — a real, comprehensive fix, not a patch that silences the finding. If a finding reveals a deeper problem than the reviewer noticed, fix the deeper problem.

8. **Re-verify.** Re-run the relevant tests or checks for what you changed. A fix that isn't verified isn't done.

9. **Report the ledger.** Give the user the agent's findings *verbatim* — one line each, quoting the finding as the reviewer stated it, not your paraphrase. Against each, lead with an icon for what you did, followed by a concise "why":
   - ✅ **fixed** — acted on it; say how.
   - 🟡 **partial/deferred** — acted in part, or left for now; say what's outstanding and why.
   - ❌ **rejected** — deliberately left; say why (wrong, out of scope, or intended behaviour).

   Example:
   ```
   ✅ Missing null check on `user.email` — added guard, returns early.
   🟡 No test for the empty-list path — covered the fix manually; unit test still TODO.
   ❌ "Rename `parse` to `parse_v2`" — out of scope; intent was the bug, not naming.
   ```

## Boundaries

- Phase 1 is read-only: neither you nor the sub-agent changes code while reflecting. All changes happen in Phase 2, by you.
- One focused agent beats a swarm. Spawn more only if the work spans genuinely independent areas that one agent can't hold at once.
- If the work is trivial, say so and skip the spawn — reflection is for work substantial enough that self-review is untrustworthy.
- Acting may reopen questions reflection answered. If your changes are substantial, it's fair to reflect again on the new state — but don't loop indefinitely. Two passes is usually enough; converge.
- Don't expand scope under cover of "the reviewer suggested it." Stay anchored to the original intent.
