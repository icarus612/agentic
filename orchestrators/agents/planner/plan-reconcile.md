# plan-reconcile — module for `--type sync` (reconcile shipped work against plan/ticket)

Type-specific guidance only; every invariant lives in the planner definition. The deliverable is a **reconciliation report** — written as `sync-report.md` inside the reconciled plan's dir — not a phased plan and not a repo sweep. If that plan is already in `completed/`, the caller reopens it first (`plan-lifecycle.sh reopen`) and passes the restored path; the planner never writes into `completed/`. The human gate is confirming the diff.

- **Truth sources:** the plan syllabus and/or the Jira ticket's acceptance criteria (at least one), versus the REAL shipped diff (`git diff <base>...<ref>` over the shipped-work reference you were given). Read the diff yourself; never trust the plan's account of itself. Explore only as supporting evidence — e.g. confirming a claimed pattern is actually in place, not just present in a hunk.
- **Classify every item** — each syllabus subphase / acceptance criterion becomes exactly one of:
  - `done` — fully implemented and verifiable in the diff/code.
  - `partial` — started but incomplete.
  - `dropped` — explicitly decided against, evidenced in diff/commits or stated by the user.
  - `diverged` — done, but differently than planned; note how, and whether the divergence respects the project's conventions.
  Cite evidence (paths, hunks) for every classification; what you can't verify is `unverified` with an open question, never a guess.
- **Report sections:** Scope & Sources (plan path, ticket key, base, shipped-work ref) · Per-Item Classification (item → status → evidence → notes) · Diff Summary · Open Questions / Unverified.
- **You change nothing else.** The record stage — after the human confirms — ticks the plan syllabus, updates docs, and transitions the ticket per your table; you only produce the table. Items the user wants actually finished are a hand-off to a build run; say so in the report rather than softening a `partial` into a `done`.
- Envelope back: `artifacts[]` = [report path]; body = the classification counts, the notable divergences, and the open questions.
