---
name: plan-format
description: How plans are named and structured — dated feature-slug markdown files with required sections, self-contained.
type: rule
domain: universal
---

# Plan format
Implementation plans are self-contained markdown files in the plans dir (see `artifact-locations`).

- **Naming.** `<feature-slug>-MM-DD-YY.md` — slug first, then date (e.g. `user-auth-07-06-26.md`). One plan per feature/change; revisions update the same file rather than spawning versioned copies.
- **Phases.** Work is broken into ordered phases; tasks are numbered `<phase>.<task>` (`4.3` = phase 4, task 3).
- **Required sections.**
  - Phase syllabus — FIRST section: HIGH LEVEL ONLY. One checkbox bullet per phase, using just that phase's section title (5 phases → exactly 5 bullets, `- [ ] Phase 4: <title>`). No task detail here — the meat of each item lives in its phase section below. It exists purely so anyone can see at a glance which work is complete: phases are checked off (`- [x]`) as they finish, or annotated in place as `- [done]`/`- [dropped]` when a phase closes without shipping as planned.
  - Goal & scope — what's in, and explicitly what's out.
  - Stack & MAJOR versions — with the manifest/lockfile each was verified from.
  - Conventions to enforce — hard constraints, not suggestions.
  - Phased tasks — one section per syllabus bullet, matching its title; tasks numbered `<phase>.<task>`, each naming the files touched, the existing pattern/example to follow, acceptance criteria, and the test approach.
  - Risks, open questions, decision points — with options where a human must choose.
  - Skill mapping — which agent skills execute which parts.
- **Living document.** The plan is not write-once: skills that record completed work (e.g. the documenting skill) update the syllabus — `- [x]` for finished phases, `- [dropped]` for abandoned ones — and annotate dropped or changed tasks in the phase sections, so the syllabus always reflects reality.
- **Self-contained.** Readable without the conversation that produced it; cite the source of every load-bearing fact.
- **NEVER include time estimates.** No durations, effort estimates, story points, or delivery dates anywhere in a plan — agents always get them wrong. Order and dependencies express sequencing; nothing expresses time.

This rule is format and placement only — how to arrive at the plan's content is the planning skill's job.
