---
name: plan-format
description: How plans are named and structured — dated feature-slug markdown files with a required subphase syllabus, lane/dependency annotations, required sections, self-contained.
domain: universal
---

# Plan format
Implementation plans are self-contained markdown files in the plans dir (see `artifact-locations`).

- **Naming.** `<feature-slug>-MM-DD-YY.md` — slug first, then date (e.g. `user-auth-07-06-26.md`). One plan per feature/change; revisions update the same file rather than spawning versioned copies.
- **Phases & subphases.** Work is broken into ordered phases, and EVERY phase decomposes into numbered subphases `<phase>.<subphase>` (`4.3` = phase 4, subphase 3) — a phase with no subphase entries is a format violation; a single-item phase still gets a `N.1`. The **subphase is the unit of work, of dispatch, and of check-off**: it's what a builder agent is handed and what gets ticked in the syllabus.
- **Required sections.**
  - **Phase syllabus** — FIRST section: TITLE ONLY at both levels. One bullet per phase acting as a grouping header, with one nested checkbox per subphase — every subphase in the plan appears here (the checkboxes that matter are the subphase entries; phases are just headers). No task detail — the meat of each subphase lives in its phase section below. Subphase entries carry OPTIONAL annotations, written only when they carry information:
    - `(after: <ids>)` — this subphase depends on the listed subphase IDs. No annotation = independent.
    - `(lane <X>)` — parallel-lane membership, when the plan declares lanes for concurrent builders. No lanes = one lane, single-builder execution.

    The syllabus exists so anyone can see at a glance which work is complete — subphases are checked off (`- [x]`) as they finish, or annotated in place as `- [done]`/`- [dropped]` when one closes without shipping as planned — and so an orchestrator can dispatch from it: lanes and `after:` edges are the schedule.
  - Goal & scope — what's in, and explicitly what's out.
  - Stack & MAJOR versions — with the manifest/lockfile each was verified from.
  - Conventions to enforce — hard constraints, not suggestions.
  - Phased subphases — one section per phase, matching its syllabus title; one detail block per subphase, numbered `<phase>.<subphase>`, each naming the files touched (its **file scope**), the existing pattern/example to follow, acceptance criteria, and the test approach. Every syllabus checkbox has exactly one matching detail block.
  - Risks, open questions, decision points — with options where a human must choose.
  - Skill mapping — which agent skills execute which parts.
- **Parallel lanes.** When the plan declares lanes: subphases in different lanes with no `after:` edge between them MUST have disjoint file scopes (they may run concurrently in the same worktree), and shared touchpoints (package manifests, barrel exports, route registries, migration indexes — examples only) get their own serialized integration subphase rather than being touched from two lanes.
- **Format is fixed, shape is proportional.** The structure above holds whether the plan has 2 subphases or 20. Phase count, subphase count, lanes, and annotations all come from the actual work: a small or genuinely serial ask plans as one lane with no annotations, and nothing forces it to invent phases or fake parallelism.

A multi-lane syllabus:

```markdown
## Phase syllabus
- [ ] Phase 1: Database schema
  - [ ] 1.1: Add user + session tables        (lane A)
  - [ ] 1.2: Migration + seed data            (lane A, after: 1.1)
- [ ] Phase 2: API endpoints
  - [ ] 2.1: Auth routes                      (lane B, after: 1.1)
  - [ ] 2.2: Profile routes                   (lane B, after: 1.1)
- [ ] Phase 3: Frontend components
  - [ ] 3.1: Login form                       (lane C)
  - [ ] 3.2: Profile page shell               (lane C)
- [ ] Phase 4: Integration
  - [ ] 4.1: Wire frontend to API             (after: 2.1, 2.2, 3.1, 3.2)
```

An equally compliant minimal, single-lane syllabus:

```markdown
## Phase syllabus
- [ ] Phase 1: Settings page updates
  - [ ] 1.1: Add notification toggles section
  - [ ] 1.2: Persist toggle state
- [ ] Phase 2: Verify
  - [ ] 2.1: Component tests + e2e pass
```

- **Living document.** The plan is not write-once: skills that record completed work (e.g. the documenting skill) update the syllabus — `- [x]` per finished subphase, `- [dropped]` for abandoned ones — and annotate dropped or changed subphases in the phase sections, so the syllabus always reflects reality.
- **Self-contained.** Readable without the conversation that produced it; cite the source of every load-bearing fact.
- **NEVER include time estimates.** No durations, effort estimates, story points, or delivery dates anywhere in a plan — agents always get them wrong. Order and dependencies express sequencing; nothing expresses time.

This rule is format and placement only — how to arrive at the plan's content is the planning skill's job.
