# plan-migration — module for `--type migration` (version bumps, library swaps, API migrations)

Type-specific guidance only; every invariant lives in the planner definition.

- **Phase shape: inventory → transform → verify-equivalence.** First an inventory subphase enumerating every affected site (a countable list with paths — the plan's ground truth for "done means all of them"); then transform subphases grouped into lanes over disjoint slices of that inventory; then an equivalence verification tail.
- **Pin the target idioms from manifests.** The plan names the exact target MAJOR version/library and the idiom mapping (old pattern → new pattern, with a real example of each from the codebase or the target's docs). Transform subphases follow the mapping mechanically; anything the mapping doesn't cover is a decision point, not an improvisation.
- **Test oracle default: `equivalence check`** — behavior before == behavior after: the existing suite passes on the migrated code, plus whatever the plan defines as the equivalence run (same outputs on the same inputs, build artifacts comparable, contract tests of the old surface running against the new one). Declare per subphase what its equivalence run actually is.
- **Escalate sweep-shaped work.** If the inventory comes out as one identical transform × many independent files with no coherence requirement, say so in your envelope — that shape belongs to a mechanical-sweep harness, not builder lanes; plan only the parts needing judgment.
