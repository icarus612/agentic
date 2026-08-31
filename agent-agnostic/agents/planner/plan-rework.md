# plan-rework — module for `--type rework` (refactors, restructures, behavior-preserving rewrites)

Type-specific guidance only; every invariant lives in the planner definition.

- **Test oracle default: `existing suite`.** Tests written before the change are the strongest anti-cheat oracle available — the plan's contract is "the suite passes unchanged." Builders spawn no contract-testers for these subphases. If coverage over the reworked area is too thin to be an oracle, add an explicit EARLY subphase to backfill characterization tests against CURRENT behavior (that subphase's oracle is `new contract tests`), before anything moves.
- **Externally-visible behavior is frozen.** Any intentional behavior change hiding inside the rework must be surfaced as a decision point (or split into a separate feature/bugfix run) — never smuggled into a rework subphase.
- **Delete-the-old-path subphases are mandatory.** Every replaced structure gets a subphase that removes it — no dual old/new paths, no compatibility shims, no versioned names surviving the run. The deletion subphase's acceptance criterion includes a dangling-reference check.
- **Lane shape.** Decompose along the seams being reworked; the old-path deletions usually serialize after the lanes that reroute callers.
