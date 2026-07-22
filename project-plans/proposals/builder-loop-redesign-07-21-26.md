# Builder loop redesign — design summary

Working brief for the dev-workflow build-loop update. Captures the discussion, the
decisions made, the open questions, and the pros/cons behind each option. Not yet a
`plan-format` plan — this is the design rationale that would feed one.

Repo context: this is the agentic repo, the single source of truth for skills/rules/hooks.
Changes edit here → `push-main` → sync universal content to `~/.claude/`. No worktrees/PRs.

---

## 1. Changes already made this session (staged, not yet pushed)

1. **`debug` → diagnose-and-report only (never writes).** Debug finds the root cause,
   reports it with a fix recommendation, and routes to `code` (implement) or `test` (verify);
   it may add temporary probes but must revert them. Only the fix itself was removed from its
   job — investigation probes are allowed, then reverted.
   - Files: `generic/skills/debug/SKILL.md` (core rewrite), plus references in
     `generic/skills/code/SKILL.md`, `generic/skills/test/SKILL.md`,
     `orchestrators/skills/dev/SKILL.md`, `docs/pipeline.md`, `generic/AGENTS.md`.

2. **`plan` → separation outranks the builder-count target.** When lanes might overlap and
   the overlap can't be cleanly hoisted into a serialized integration subphase, merge them
   into one lane. Fewer non-colliding builders beats more possibly-colliding ones; when unsure
   whether two lanes overlap, treat it as overlap and serialize.
   - File: `generic/skills/plan/SKILL.md` (step 5).

Both are universal-domain and would sync to `~/.claude/skills/` after push.

---

## 2. Core concepts established

### Contract-first (spec-first) testing
- **Contract** = what the code *should* do (the plan/acceptance criteria).
  **Implementation** = what the code *actually* does. A bug is a gap between them.
- The danger: if a test author sources expected values by **reading what the code does**,
  the test just re-encodes the code — **including its bugs** (a tautological / self-confirming
  test). It looks thorough (green, good coverage) while verifying nothing.
- Contract-first = derive expected values from the **plan**, independent of the implementation,
  so the code can't bias what "correct" means. Fires exactly where impl diverges from contract.
- Limit: contract tests are **coarse** — they catch spec violations but are blind to
  implementation-specific failure modes the plan never imagined.

### Implementation-aware testing (the complement)
- Reads the actual code and targets its specific risk paths (null branch, overflow, the one
  loop with an off-by-one). Catches "right thing done wrong on this specific path."
- Requires reading the code → inherently a **post-code** step.
- The strong suite carries **both**: contract tests + implementation-aware tests.

### The two failure modes, and how ordering selects one
- **Tautology** (test mirrors code) vs **drift + blindness** (test & code don't fit, and no
  one inspects the real code).
- In a **single context**, whichever artifact is authored *second* can cheat off the first:
  - code-first → test can peek at code (tautology).
  - test-first → code can code-to-the-test (reverse tautology / overfit).
- So order doesn't remove the risk — it **selects which risk** you inherit.
- Only **isolated forks** eliminate *both* cheats structurally (neither sees the other).

### Two more invariants
- **The verify step is always a serial join.** Running tests against code needs both to
  exist — no ordering removes that barrier. Authoring can parallelize; checking cannot.
- **`code` must NOT validate against the tests.** Coding-to-the-test is Goodhart's law: the
  test becomes a target and stops being a measure (hardcode the inputs, satisfy the letter).
  `code`'s target is the **plan**; green is a consequence, not the goal. The loop already
  protects this — `code` consumes `debug`'s *diagnosis*, not the raw failing test.

---

## 3. Two candidate builder-loop architectures

### A) Sequential, single-context, dual-source  — RECOMMENDED DEFAULT
```
plan slice
  → test-contract   author tests from the PLAN — zero code preview
  → code            implement the contract (don't overfit to visible tests)
  → test-impl       read code, add impl-aware tests, RUN all, break loop if green+faithful
  → debug           on red: diagnose vs plan, route back (never writes)
  ↑___ code fixes → re-run ___|
  → test-impl EXITS when green AND faithful to the plan
```
- **Pros:** gets contract-first quality + impl-aware coverage + clean failure attribution,
  all in one context. No dependency on unverified nested spawning. Cheap; no per-subphase
  overhead. Small delta from today's skills.
- **Cons:** authoring is serial (no code‖test parallelism). Tautology-resistance for the
  contract tests is *structural at authoring time* (they're written before code exists) but a
  single context can't stop the same agent from later weakening a contract test to match buggy
  code — that residual tampering risk is covered by discipline + the impl-aware pass +
  `review-code`, not structurally.

### B) Parallel fork + contract expansion  — ESCALATION for large slices only
```
builder: expand contract (internal interface, no approval)
  → fork code ‖ fork test-contract     isolated — neither can see the other
  → debug (JOIN): run tests vs code; verify code↔plan, test↔plan, code↔test; diagnose
  → test-impl (reads code): add impl-aware tests + run
  → debug → loop → exit
```
- **Pros:** structural cheat-proofing (isolated forks can neither peek nor overfit). Interface
  drift killed at the source by the shared expanded contract. Real authoring parallelism.
- **Cons / costs:**
  - **Loses impl-aware-at-authoring** — the test-contract fork never sees code, so the
    impl-aware tests are an unavoidable **serial tail** after the join.
  - **Overhead only amortizes on large subphases** (serial expansion prefix + heavier debug
    join + 2 forks of budget). Small subphases are faster/cheaper sequential.
  - **Depends on nested subagent spawning** (see §4) — unverified.
  - **Shared-contract single point of error:** a wrong expanded contract propagates
    *identically* into code and test, so they agree with each other → code↔test check passes.
    Only the **code↔plan / test↔plan** checks catch it. Those plan checks are therefore
    load-bearing, not optional.
  - **Approval boundary:** the expansion is "no approval" ONLY for internal interface detail.
    Anything that changes externally-visible behavior or contradicts the approved plan must
    escalate back to the human gate — no silently expanding out of scope.
  - **debug stays diagnose-only:** if the contract is insufficient, debug REPORTS that and
    routes back to the builder's expansion step; debug does **not** rewrite the contract itself
    (keeps one owner per artifact, consistent with the debug change in §1).

**Recommendation:** A is the everyday loop; B is a per-subphase mode chosen only when a slice
is large and well-specified enough to earn the overhead — and only after §4 is verified.

---

## 4. The load-bearing unknown: can a builder spawn sub-agents?

- The parallel model (B) requires the **builder** (itself an Agent-tool subagent) to fork
  `code` / `test-contract` into isolated contexts → **nested subagent spawning**.
- Signals: the `builder` agent type lists "All tools" (includes Agent) → suggests yes. But the
  Workflow tool enforces "nesting is one level only" → the platform limits recursion somewhere.
- **Not verified.** It decides *where the parallel loop can live*:
  - Nesting works → builder is a self-contained mini-orchestrator per lane (design stays in the
    builder).
  - Nesting blocked → parallelism must hoist up to the `dev` orchestrator (builder-as-single-
    context-loop dissolves for that mode; the dev skill becomes involved after all).
- Cheap to verify empirically (spawn a builder-type agent, have it try to spawn a trivial
  sub-agent). Do this before building on B.

---

## 5. Concurrency cap ("5")

- **`cap 5 per wave` is a convention in `dev/SKILL.md:70`, not a hard system limit** — editable text.
- It's conservative on purpose: builders **share one worktree with no lock**, so more
  concurrent builders = more collision surface. The cap bounds blast radius — the same
  "fewer-over-overlap" principle from §1.
- `context: fork` is **not** the parallelism knob; the **Agent tool** is. Forked skills are
  invoked sequentially ("never wrap a forked skill in an Agent-tool spawn").
- To raise it *safely*, pair it with **per-builder worktree isolation** (`isolation: 'worktree'`
  + merge between waves) so concurrency stops meaning collision. Cap and isolation move together.
- For genuinely large deterministic fan-out, the **Workflow tool** is the built-for-it machine
  (managed concurrency `min(16, cores-2)`, up to 1000 agents lifetime, 4096 items/call).
- Intra-lane note: `code` and `test-contract` forks naturally write **disjoint files** (impl vs
  test files), so within-builder collision is low — EXCEPT inline-test stacks (Rust
  `#[cfg(test)]`, doctests) where they'd share a file.

---

## 6. Skill granularity — the decision rule

**Mint a new skill only when write-authority, exit-authority, or dispatch-point changes.**
If only *sourcing* or *timing* changes, that's a **phase inside a skill**, not a new skill.
Steps ≠ skills. Fragmentation costs: handoff surface grows ~N², more files to sync/maintain,
loop invariants get harder to state.

Applied:
- **code / test / debug are the real authority joints.** Keep.
- **debug must NOT be split** into debug-a/debug-b — same authority, same process, differ only
  in trigger. One adjudicating diagnostician (verdicts: code wrong / test wrong / contract wrong).
- **test split into two IS justified** — but by a genuine contract difference, not timing:
  one is *forbidden from reading the implementation*, the other *requires* it.

---

## 7. Decided change (pending naming): break `test` into two skills

- **`test-contract`** (name TBD) — the **zero-code-preview** skill. Authors tests SOLELY from
  the plan/contract; never reads/previews the implementation. Runs at the top of the loop
  (before code) or as an isolated fork. **Pure authoring: does not run tests, does not break
  the loop** (it hasn't seen code, so it can't verify). Hands to `code`.
- **`test-impl`** (name TBD) — today's `test`, refocused. Reads the real code, adds
  implementation-aware tests, RUNS the full suite (contract + impl), and is the **sole
  loop-breaker**. Red → `debug`; missing impl → `code`; green + faithful → exit.
- **`debug`** — unchanged (diagnose-only, never writes, routes).
- **`code`** — add one line: contract tests may already exist; target the plan, never hardcode
  to the tests.

Splitting test this way creates a **real authority difference** (test-contract never exits;
test-impl runs + exits), which is what makes it a legitimate split rather than two phases.

**Updated loop invariants:**
- Only **`test-impl`** breaks the loop (was "only test").
- **`test-contract`** never exits and never reads code.
- **`debug`** never writes.
- **`code`** is the only implementation writer.

**Loop:** `test-contract → code → test-impl → (debug ⇄ code) → test-impl exits`

---

## 8. Open decisions before implementing the test split

1. **Names** for the two skills — user is clarifying (naming question was paused). Candidates
   floated: `test-contract`+`test-impl`, `test-spec`+`test-code`, `test-dd`+`test-impl`.
2. **Rename vs add** — rename `test/` → `test-impl/` + new `test-contract/` (clean names, bigger
   ripple) vs keep `test` as the runner + add `test-contract` (less ripple, slight asymmetry).
   Leaning rename for clarity in a source-of-truth repo.
3. **Sequential now, parallel later?** — recommend wiring the sequential default loop now and
   keeping the two skills forward-compatible with the parallel model, rather than wiring forks
   before §4 is verified.
4. **Verify nested spawning (§4)** before committing to the parallel escalation path.

**Files the test split would touch:** new `generic/skills/test-contract/SKILL.md`; rename+refocus
`generic/skills/test/` → `test-impl/`; handoff refs in `code`/`debug` SKILLs; `dev` orchestrator
(loop rules, pipeline line, builders preload **four** loop skills); `docs/pipeline.md`,
`generic/AGENTS.md`, `README.md`; then `push-main` + sync.
