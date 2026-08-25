# report-skeleton — the fixed frame `report.md` fills

Consumed by `report.md` stage 3; produces the report artifact in either ship mode. This is a TEMPLATE PLUS ITS RULES, not prose about reports. The frame below is FIXED — five sections, this order, these titles, for both `map` and `analyze` — and it is filled IDENTICALLY at both types: only the *content* of sections 2 and 4 reflects the resolved axes. Never add a per-type variant of this file, and never rename or reorder the five sections; a reader who sees a sixth section, a missing one, or these titles in a different order is looking at a defect, not a stylistic choice.

## The frame

```markdown
## Question as asked

## Method

## Findings

## Evidence

## Confidence + open questions
```

## Section rules

### 1. Question as asked

The user's question, VERBATIM. Not a restatement, not a cleaned-up version, not a paraphrase. If the ask arrived across several turns, quote what was actually asked across them — never silently narrow it to the last message.

### 2. Method

The resolved depth and rigor, what was read, and — separately — what was TRUSTED. At DEEP explore, state explicitly that the docs are distrusted as ground truth and the code is trusted instead; a reader must be able to tell, from this section alone, which artifact this report would defer to on a conflict. At `rigor ≥ med`, name the committee's width (3 or 5) and point at the consolidated `accepted.md` — never at an individual member's claim file.

### 3. Findings

The ONLY free-organization zone in the whole report. Sections and subheadings here are the model's to choose per question — state that explicitly, so a reader doesn't mistake the fixed frame around this section for a fixed shape inside it. Its one constraint: every finding carries its evidence by reference to section 4, never as a floating assertion with no anchor. When the question is a general triage ("what's wrong with X"), each finding additionally carries the **security / scope / experience-breaking** ratings — the same three the diagnosis report uses.

### 4. Evidence

`file:line` for EVERY claim. A claim that cannot be anchored to a location is not a finding — move it to section 5 as an open question instead of leaving it unanchored here. At `rigor ≥ med`, evidence sources from the committee's consolidated `accepted.md`.

### 5. Confidence + open questions

The confidence statement, plus what could not be determined. Cold forks cannot ask mid-run: an unresolved question becomes a flagged open question here, never a guess and never a phase the run invokes for itself. At `rigor ≥ med`, a claim still unverified at consolidation lands here, flagged unverified, rather than being dropped — a report includes what it couldn't confirm instead of silently discarding it.
