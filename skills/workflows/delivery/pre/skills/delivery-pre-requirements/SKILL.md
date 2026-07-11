---
name: delivery-pre-requirements
description: Explore and capture user requirements (ask, narrative, acceptance criteria) and link Jira tickets before implementation begins.
type: workflow
domain: delivery
rules: [verify-dont-assume]
model: sonnet
model-fallback: [gemini-pro]
---

This is the PRE cycle of the delivery workflow. Before any code is written, you explore and capture what the user actually wants and why. You produce a structured requirements artifact that anchors both the dev work and the POST cycle's published documentation. You capture the original ask verbatim, the story/narrative behind it, acceptance criteria, constraints, and stakeholders, and you identify or create the governing Jira ticket(s) via the Atlassian MCP server.

## When to use

- Use this at the very start of a story, after delivery-start has set up the run and delivery-connect has confirmed Atlassian + Google Drive connectivity.
- Use it whenever you need a single source of truth for "what we're building and why" that the dev workflow and POST publishing will both reference.
- Do not use this to publish finished docs (that is delivery-post-confluence) or to write a changelog (delivery-post-changelog).

## How it works

1. **Capture the original ask verbatim.** Record exactly what the user requested, in their words, without paraphrasing or "improving" it. This raw ask is the anchor everything else is checked against.
2. **Draw out the story / narrative.** Through conversation with the user, capture who needs this and why: the affected users or stakeholders, the problem or pain, the user journey today, and the desired journey after the change. This "why" is what distinguishes story docs from the dev workflow's technical-only in-repo /docs.
3. **Define acceptance criteria.** Capture concrete, verifiable conditions for "done" - ideally testable statements. If the user has not stated them, propose criteria and confirm each one with the user.
4. **Record constraints and stakeholders.** Note technical, time, compliance, and scope constraints, plus the people who must review, approve, or be informed.
5. **Identify or create Jira ticket(s).** Search the Atlassian MCP server for an existing Jira issue that governs this story. If none exists, work WITH the user to create one (do not invent scope or open tickets unilaterally). Record every relevant Jira issue key - the POST cycle (delivery-post-jira-link) will link published pages back to these.
6. **Produce the structured requirements artifact.** Write a single structured document containing: Original Ask (verbatim), Story / Narrative, Acceptance Criteria, Constraints, Stakeholders, and Jira issue key(s). Keep it text-only. If the user supplies large or binary supporting material (mockups, datasets, exports), upload those to Google Drive via the Drive MCP and reference them by shareable link only - never attach large/binary artifacts to Jira/Confluence (the ~2 GB Atlassian cap; see delivery-drive-archive).
7. **Verify with the user.** Read the artifact back, section by section, and get explicit confirmation. Do not invent or assume requirements - flag every gap and let the user fill it. Only mark the artifact ready once the user confirms it.

## Hand-off / next

- Hand the confirmed requirements artifact and the Jira issue key(s) to the dev workflow (dev-start) so implementation builds on agreed scope.
- The POST cycle reads this artifact directly: delivery-post-confluence reuses the Original Ask + Story/Narrative so the published page covers both the why and the technical work, and delivery-post-jira-link links published pages to the Jira issue key(s) captured here.
- For any large/binary supporting files, coordinate with delivery-drive-archive to keep them in Google Drive with links surfaced here.

## Notes

- Verbatim matters: preserve the user's exact ask so later docs and reviewers can trace decisions back to the original request.
- Story over task list: capture user need and journey, not just a checklist - this is the core value the delivery workflow adds over dev's technical docs.
- Never invent requirements or acceptance criteria; propose, then confirm.
- Keep this artifact text-only; large or binary assets live in Google Drive and appear here as links, honoring the ~2 GB Atlassian cap.
