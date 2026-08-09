# plan-diagnosis — module for `--type diagnose` (root cause unknown)

Type-specific guidance only; every invariant lives in the planner definition. The deliverable is NOT a phased plan: it is a **ranked candidate-cause report**, written as `proposals/<slug>-MM-DD-YY.md` and becoming the run's `plan.md` on promotion. The report IS the plan; the human gate is picking the cause(s) to fix.

## Investigation discipline

- **Diff first (cheap), explore only if needed.** Compute the real diff between the base branch and the suspect reference (`git diff <base>...<ref>`; for merged work, locate the merge/commits first). Read it yourself — it is frequently enough to form hypotheses. Escalate to a deep `explore` fork only when the diff plus the issue don't localize the suspect area.
- **Reproduce** the failure deterministically where you can — exact command, input, observed-vs-expected. If you cannot reproduce, say so; do not guess.
- **Locate along the real flow.** Trace actual data/control flow; diagnose the cause, not the symptom. Every hypothesis is backed by evidence (a log, a narrowed test, a temporary probe) — and every probe is REVERTED before you move on.
- **Never write a durable fix.** Investigation produces diagnoses; fixes belong to builders after the gate.

## Fan-out (the countable rule)

For an ambiguous issue with several plausible suspect areas, spawn **one investigation subagent per distinct suspect area**, batched in a single message so they run concurrently (cap 5). Each applies the discipline above to its area and returns the shared envelope with body fields: `root_cause`, `evidence` (paths/hunks/repro), `likelihood High|Med|Low`, `ease High|Med|Low`, `proposed_fix`, `files`. A simple, localized issue is investigated inline instead — spawning is for breadth, not ceremony.

## Rank and report

Dedupe the surviving hypotheses, then rank on **likelihood × ease** — likelihood first (how strongly the evidence supports this being the ACTUAL cause; an unverified guess is Low however plausible), ease as tie-break (implement AND verify: blast radius, test surface, convention fit). Report sections: Scope & Sources (issue verbatim / plan path / Jira key, base, suspect ref) · Reproduction (or an honest "couldn't") · **Ranked Candidates** (a checkbox list, one `- [ ] C<n>:` entry per candidate, each with likelihood, ease, evidence, proposed fix, files it touches — the files list is the fix lane's file scope, and the entry is its detail block) · Diff Summary · Open Questions / Unverified.

- **Test oracle for fix lanes:** the reproduction — a fix is verified when the repro no longer triggers and the existing suite stays green; candidates whose fix adds behavior declare `new contract tests` for that part.
- Envelope back: `artifacts[]` = [report path]; body = the top of the ranking and what could not be verified. Present the full ranking; the pick is the human's, not yours.
