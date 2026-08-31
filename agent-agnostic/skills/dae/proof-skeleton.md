# proof-skeleton — the fixed frame `prove.md` fills

Consumed by `prove.md` stage 6; produces the proof artifact in either ship mode. This is a TEMPLATE PLUS ITS RULES, not prose about proofs. The frame below is FIXED — six sections, this order, these titles, for every run regardless of verdict or rigor — and it is filled IDENTICALLY across all of them: only the *content* of sections 3, 4, and 5 reflects the resolved axes. Never add a per-type variant of this file, and never rename or reorder the six sections; a reader who sees a seventh section, a missing one, or these titles in a different order is looking at a defect, not a stylistic choice.

## The frame

```markdown
## Claim under test

## Verdict

## Method

## Proof

## Falsification attempt

## Confidence + what would change the verdict
```

## Section rules

### 1. Claim under test

The claim, verbatim, exactly as fixed at `prove.md` stage 3. Never a cleaned-up restatement, a narrowed version, or a paraphrase — a narrowed or rephrased claim is a *different* claim, not the same one tidied up, and this section exists precisely to make substitution impossible to hide.

### 2. Verdict

Exactly one of `proved` | `disproved` | `inconclusive`, on its own line, before any prose. The vocabulary is CLOSED — no synonyms, no hedged variants, nothing invented to soften an uncomfortable result. `inconclusive` is a first-class outcome in its own right and must never be dressed up as a weak `proved` or a weak `disproved`; if the evidence does not settle the claim, this is where that gets said plainly.

### 3. Method

The resolved depth and rigor, what was read, and — separately — what was TRUSTED. At `rigor ≥ med`, name the committee's width and point at the consolidated `accepted.md`, never at an individual member's claim file (mirrors `report-skeleton.md`'s Method rule).

### 4. Proof

The free-organization zone — state this explicitly, with one constraint: every step is anchored, either `file:line` or a command together with its actual output. An unanchored assertion is not proof; it belongs in section 6 as an open confidence caveat, not here dressed up as evidence.

### 5. Falsification attempt

What was tried in order to refute the claim, and what happened when it was tried. State, as an explicit rule: a section saying nothing was tried is a **defect**, not a strong result — it is the difference between a proof and an opinion, and an empty section here invalidates the verdict above it rather than merely weakening it.

### 6. Confidence + what would change the verdict

The confidence statement, plus the concrete observation that would flip the verdict. State plainly: a proof that nothing could falsify is either a tautology or an unfalsifiable claim, and this section must say which one it is — silence here is not an acceptable answer.

Never add a per-type variant of this file: the frame is identical whether the verdict lands `proved`, `disproved`, or `inconclusive`, and identical across rigor tiers — only the *content* of Method, Proof, and Falsification attempt reflects the resolved axes. Never rename or reorder the six sections.
