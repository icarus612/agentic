# plan-feature — module for `--type feature` (and the additive default)

Type-specific guidance only; every invariant lives in the planner definition.

- **Anchor on the story.** Acceptance criteria come from the user's ask (and the story file, when the run captured one — its criteria become plan constraints verbatim). Every phase should trace to a stated need; scope creep goes to the decision-points section, not into subphases.
- **Test oracle default: `new contract tests`.** The acceptance criteria are the contract; write them concrete enough that a blind test author can derive executable tests from the detail block alone. A subphase extending behavior the existing suite already covers may declare `existing suite` instead.
- **Lane shape.** Features are the type most likely to decompose well: aim for 2–5 lanes along module/layer boundaries (per the disjointness invariant), with integration subphases serialized at the end of the graph.
- **New surface area needs a home.** Any new module, route, or package gets a subphase naming exactly where it lands and the existing example it mirrors — "somewhere sensible" is not a file scope.
