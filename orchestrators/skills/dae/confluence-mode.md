# confluence-mode — requirements capture and the story file

Applies when `CLAUDE_DOCS_PUBLISH` is set. The local docs tree is the source of truth in every configuration (see `artifact-locations`) — this file is not about where docs live. It covers Jira/requirements capture, which is independent of where docs live and is triggered by ticket-tracked work.

## Capture requirements BEFORE exploring (conversational)

Forks can't converse, so gather this with the user up front:

- The original ask **VERBATIM** — their words, no paraphrasing.
- The story/narrative: who needs this and why; the journey today vs after.
- Acceptance criteria — propose, then confirm each; never invent.
- Constraints and stakeholders.
- The governing Jira issue key(s) — search via the Atlassian MCP; if none exists, create one WITH the user. Never invent keys or open tickets unilaterally.
- The publish targets: confirm the Confluence space and parent page parsed from `CLAUDE_DOCS_PUBLISH`, and the Google Drive folder for large-artifact offload — these are CI's targets, confirmed with the user once rather than per run; ask rather than assume, a wrong space, key, or folder corrupts everything downstream.

## The story file

Once the parent worktree exists, write the capture as `proposals/<slug>-MM-DD-YY.story.md` inside the plans dir in the working directory (resolve via `resolve-config.sh CLAUDE_PROJECT_PLANS_DIR --default /project-plans/`), using the run's slug. Sections: Original Ask (verbatim), Story / Narrative, Acceptance Criteria, Constraints, Stakeholders, Jira issue key(s), resolved Confluence/Drive targets. It moves into the plan's dir as `story.md` at promotion; the planner consumes it (its acceptance criteria become plan constraints). `story.md` satisfies `plan-format`'s ask-of-record pointer — the same mechanism as a plain run's `the-ask.md`, not a second artifact. Do not generalize the story file to every run: it carries Jira keys, stakeholders, and publish targets a plain ask does not need; the ask pointer names whichever durable artifact exists, `the-ask.md` or `story.md`.

The record stage is `document-local`, always — it writes the local docs tree regardless of `CLAUDE_DOCS_PUBLISH`. Publishing that tree to Confluence is a CI job on merge, not a step of this run; `document-confluence` is manual recovery only, for when CI has not run or has failed. Neither is described here — see `document-local` and `document-confluence`.
