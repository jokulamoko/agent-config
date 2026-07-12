---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
---

Write a handoff: a document that lets a fresh agent — with no memory of this
conversation — pick up the work and take the next action. Save it to the user's
OS temp directory, not the workspace.

It is done only when a fresh agent could resume from the doc alone, without the
conversation it replaces.

Capture what lives only in this conversation. Point at docs,
commits, and diffs by path or URL rather than restating them — the conversation-only
knowledge is the payload:

- the full design of the work discussed. Not necessarily the full archeology, but at a minimum all the final
design decisions, including any subtle calls. Include comprehensive detail.
- current state — what's done, what works, what's mid-flight
- dead ends already tried, and why they failed, so they aren't repeated
- the live hypothesis or mental model behind the current approach
- the exact next action to take
- suggested skills the next agent should invoke

Redact secrets and PII — API keys, passwords, tokens, personal data.

If the user passed arguments, treat them as the focus of the next session and
tailor the doc to it.