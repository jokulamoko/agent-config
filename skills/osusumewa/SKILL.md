---
name: osusumewa
description: Don't decide silently and don't dump an unstructured wall of considerations — lay out a small set of genuinely distinct, viable options for the user to review, each with its trade-offs stated relative to the others and given impartial treatment, then close with a clear recommendation and the reasoning behind it. Use whenever the work reaches a real fork: an architecture or design choice, a library pick, a naming call, an approach with no single obvious answer ("what are my options", "how should we do this", "give me a recommendation").
disable-model-invocation: false
---

# Osusumewa

おすすめは — "my recommendation is…". When the work hits a genuine fork, the user wants
neither of the two lazy ends: a silent unilateral pick that hides the decision, or an
even-handed wall of considerations that pushes the whole decision back onto them. They
want **options worked up for review, with a recommendation** — your judgement made
legible and challengeable.

## What to produce

1. **Find the real axis.** Before listing anything, name what actually differs between
   the choices — the dimension the decision turns on (simplicity vs flexibility, speed
   now vs speed later, blast radius, reversibility). If you can't name the axis, you
   haven't understood the decision yet. The options are points along that axis.

2. **2–4 genuinely distinct, viable options.** Every option must be one a reasonable
   person might actually choose — no straw men padded in to flatter the recommendation.
   They must be mutually exclusive real choices, not the same idea reworded. If two
   collapse into one, merge them; if you only have one real option, say so plainly and
   skip the ceremony.

3. **Relative trade-offs, not absolute.** State each option's trade-offs *against the
   others* — what you gain and give up by taking this one **instead of** its rivals.
   "Cheaper" is meaningless; "cheaper to build but the harder of the two to change later"
   is the point.

4. **Impartial treatment until the recommendation.** While laying the options out, give
   each one a fair, even hearing — present its real upside, not a token nod before you
   knock it down. Don't tilt the trade-offs toward your preferred option or telegraph
   the verdict; the reader should be able to weigh them honestly before seeing where you
   land. The favouritism comes later, in the recommendation, and only there.

5. **A clear recommendation, at the end, with reasoning.** After the options stand on
   their own, close with the one you'd pick and *why* — which trade-off you weighted most
   and what assumption that rests on. Don't hedge back to neutrality; the recommendation
   is the value. Name the condition that would flip it ("…unless we expect to support N
   more of these, then option 2").

## Form

- Lay out all the options impartially first, then the recommendation at the bottom. Label the おすすめ explicitly at the bottom.
- One concept per option; tight, comparable trade-offs (ideally the same axes across all
  of them so they're easy to weigh side by side).
- **Print the options straight into the chat — do not use the `AskUserQuestion` tool.**
  The user wants to read them in the conversation and answer in their own words, not
  pick from a menu. Lay them out as plain markdown (a list, or a table when several
  comparable axes make side-by-side easier), then stop and let the user reply in chat.
  Number the options so the user can answer "go with 2" unambiguously.

Per the standing rule: a recommendation is an argument, not an order — if the user
pushes back, defend it or fold on the merits.
