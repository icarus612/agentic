# diagnose — the root-cause workflow (`--type diagnose`)

For issues whose cause is UNKNOWN: investigate, rank candidate causes, gate on the human's pick, then fix only what was picked. The ranked report IS the plan. Setup and ship are the router's shared stages; gates follow the router's caps and kickback routing.

## Stages

**1. Setup** (shared — router). Branch type `bug/`. Additionally capture, conversationally, BEFORE setup completes: the **issue** precisely (freeform description/stack trace VERBATIM, a plan path, or a Jira key — fetch the ticket via the Atlassian MCP yourself; at least one source required, never invented) and the **suspect work** (`--ref`, or ask for a branch/PR/range/merge locator — never guess it from the issue text).

**2. Plan ‖ init.** Spawn the **`planner`** agent with type `diagnose` (module `plan-diagnosis`), the issue verbatim, the suspect reference, the parent worktree path, and the `--explore` override if any (this workflow's default is DEEP). The planner diffs, investigates — fanning out its own investigation subagents — and writes the ranked diagnosis report to the plans dir; its envelope points at it. `init-workspace` runs in parallel, joined before the gate.

**3. Pick-the-causes gate (human).** Present the ranked candidate table and the report. The user picks which candidate(s) to pursue — one, several, or none. **None is a valid outcome**: the report is the deliverable; skip to Record/Ship so the report is preserved, and do not invent work. Corrections or a re-rank request → SendMessage the warm planner.

**4. Fix.** Each approved candidate is a builder task: its report entry is the spec, its cited files the file scope. Group approved candidates into lanes by disjoint file scope and dispatch per `build-dispatch.md` (the report stands in for the plan; tick candidates in it via your own edit — `mark-syllabus.sh` if the report uses checkbox syllabus form). After the last merge: integration pass in the parent — full suite plus confirming the report's reproduction no longer triggers.

**5. Code gate (human).** `review-code` with the diagnosis report path (the spec of record) and the build summary; route its reason-code verdict per the router.

**6–7. Record, Ship** (shared — router). Record refreshes docs/ticket state per mode; ship publishes fix + report. The PR gate's spec of record is the **diagnosis report** (plus the Jira key when one sourced the issue): the picked candidates are the acceptance criteria, and nothing outside their cited file scopes may have changed. On a no-fix run, ship still runs — it is what preserves the report (the worktree is torn down); a declined push leaves the report path in your summary.

## Notes

- Cheapest evidence first: the planner diffs before it explores, explores before anyone fixes.
- If investigation stalls — no candidate at confident likelihood — say so plainly with what evidence is missing; never ship a low-confidence fix to tidy the report.
- If the real work turns out to be a feature or redesign, stop and recommend a build-workflow run instead.
