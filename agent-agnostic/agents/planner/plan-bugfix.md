# plan-bugfix — module for `--type bugfix` (alias `bug`, `debug`) and `--type hotfix`

Type-specific guidance only; every invariant lives in the planner definition.

- **Subphase 1.1 is ALWAYS a failing regression test** that reproduces the defect — written and observed red before any fix subphase. Its detail block states the exact reproduction (command, input, observed vs expected). No fix subphase may come before it or skip depending on it.
- **The cause is known.** This module plans a fix for a stated or established defect. If the cause is actually unknown, that's the diagnose workflow — flag the misclassification in your envelope instead of planning a guess.
- **Test oracle:** the 1.1 regression test plus `existing suite` — the fix is done when 1.1 goes green and nothing else goes red. Fix subphases normally need no new contract tests beyond 1.1; declare more only when the fix adds behavior.
- **Minimal scope.** Fix the defect, not the neighborhood; refactors the fix exposes go to the decision-points section as follow-up candidates. Under `--type hotfix` this is a hard constraint: the absolute minimum diff that makes 1.1 pass, single lane, no opportunistic cleanup.
- **Lane shape.** Usually one lane (1.1 → fix → verify). Multiple lanes only for genuinely independent defects sharing a ticket.
