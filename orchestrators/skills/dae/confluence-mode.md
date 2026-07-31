# confluence-mode — requirements capture and the story file

Applies when setup's docs target resolves to a Confluence location (an Atlassian wiki URL or `confluence:<SPACE>[/<Parent Page>]`): Confluence becomes the docs source of truth, `document-confluence` is the record stage, and no local `/docs` is maintained.

## Capture requirements BEFORE exploring (conversational)

Forks can't converse, so gather this with the user up front:

- The original ask **VERBATIM** — their words, no paraphrasing.
- The story/narrative: who needs this and why; the journey today vs after.
- Acceptance criteria — propose, then confirm each; never invent.
- Constraints and stakeholders.
- The governing Jira issue key(s) — search via the Atlassian MCP; if none exists, create one WITH the user. Never invent keys or open tickets unilaterally.
- The publish targets: confirm the Confluence space and parent page parsed from `CLAUDE_DOCS_DIR`, and the Google Drive folder for large-artifact offload — ask rather than assume; a wrong space, key, or folder corrupts everything downstream.

## The story file

Once the parent worktree exists, write the capture as `<slug>-MM-DD-YY.story.md` in the plans dir inside the working directory (resolve via `resolve-config.sh CLAUDE_PROJECT_PLANS_DIR --default /project-plans/`), using the run's slug. Sections: Original Ask (verbatim), Story / Narrative, Acceptance Criteria, Constraints, Stakeholders, Jira issue key(s), resolved Confluence/Drive targets. It sits next to the future plan file; the planner consumes it (its acceptance criteria become plan constraints) and `document-confluence` anchors the published story on it.

At the record stage, pass `document-confluence`: the parsed target (space, parent page), the Jira key(s) and Drive folder, the plan and story file paths, the build/review summary, and the changelog preference. It publishes the story + technical page and changelog page and links the Jira ticket(s) bidirectionally. A needs-input return (missing target, dead connection) comes back to the user — don't let it guess.
