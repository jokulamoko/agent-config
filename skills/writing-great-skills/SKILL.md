---
name: writing-great-skills
description: Reference for writing and editing skills well.
disable-model-invocation: true
---

# Writing great skills

A skill exists to make a stochastic agent take the same *process* every run — not produce the
same output. Everything below serves that.

## Mechanics

A skill is `.claude/skills/<name>/SKILL.md`; Claude Code and OpenCode both read it there, so a
new skill needs no symlink and no config.

**Skills do not compose, and personal beats project.** A project skill of the same name is
*shadowed* by a personal one — silently, not merged. To let a project extend a generic skill,
have the skill declare an extension point: *"if `.claude/<name>.md` exists in the repo, read it
and follow it."*

## Invocation — the one lever with a real cost

- **Model-invoked** (omit `disable-model-invocation`): the description sits in the context
  window **every turn**, so the agent can fire the skill on its own and other skills can reach
  it. You pay for that description forever.
- **User-invoked** (`disable-model-invocation: true`): no description in context, so it costs
  nothing — but *you* become the index. Nothing can reach it but you typing its name.

Choose model-invocation only when the agent must reach the skill unprompted, or another skill
must. If it only ever fires by hand, strip the description and pay nothing.

For a model-invoked description: lead with the trigger word, give **one trigger per distinct
case** (synonyms for the same case are duplication), and cut any identity the body already
carries.

## Leading words

The highest-leverage technique, and the one worth hunting for.

A **leading word** is a compact concept already living in the model's pretraining — *tracer
bullet*, *fog of war*, *lesson*, *red* — that the agent thinks *with* while running the skill.
Repeated as a **token**, never restated as a sentence, it anchors a whole region of behaviour for
almost no tokens, by recruiting priors the model already holds.

- **Reach for a pretrained word first.** Coining your own works only if you define it, and a
  made-up word recruits no priors — you pay in definition tokens what a real word gives free.
- It earns twice: in the body it anchors *execution*; in the description it anchors *invocation*,
  especially when the same word lives in your prompts, docs, and code.
- **Hunt the restatements it retires.** "fast, deterministic, low-overhead" → *tight*. "a loop you
  believe in" → *red*. Assume every skill is carrying some.

## Pruning

Three cuts, in order:

1. **No-ops.** Does the line change behaviour versus what the model does by default? "Be thorough"
   does not. Run the test on each sentence in isolation, and when one fails, **delete the whole
   sentence** rather than trim words from it. A leading word too weak to beat the default is a
   no-op; the fix is a stronger word (*relentless*), not a different technique.
2. **Duplication.** One meaning, one place. Repeating a *token* is a leading word; repeating a
   *meaning* is debt — it costs maintenance and inflates the meaning's apparent importance.
3. **Disclosure.** Push reference the agent needs only *sometimes* into a linked file, so the top
   of the skill stays legible. The **wording of the pointer**, not its target, decides whether the
   agent actually reaches it — so if must-have material is being missed, sharpen the pointer before
   pulling the material back inline.

Length is itself a defect, even when every line is live and unique.

## Steps and their criteria

Not every skill has steps — a review is all reference, and that is fine. Where a skill *does* have
ordered steps, each ends on a **completion criterion**: the condition that tells the agent it is
done. Make it

- **checkable** — can the agent tell done from not-done? A vague bound ("understanding reached")
  lets it declare victory and slide to the next step; and
- **exhaustive** where it matters — "every modified model accounted for" beats "produce a change
  list". This is what drives real digging rather than a token pass.

If you watch the agent rush a step, **sharpen the criterion first** — that is cheap and local.
Only split the skill to hide the later steps if the bound is irreducibly fuzzy *and* you have
actually observed the rush.
