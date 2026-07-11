---
name: delivery-post-confluence
description: Publish Confluence page(s) documenting the technical work plus the original ask and story narrative after implementation.
type: workflow
domain: delivery
rules: [verify-dont-assume, push-policy, external-storage-cap]
model: sonnet
model-fallback: [gemini-pro]
---

After implementation lands, you publish the canonical documentation to Confluence. Unlike the dev workflow's in-repo `/docs` (technical only), the Confluence page must tell the whole story: WHY the work was done, the user need and journey captured in delivery-pre-requirements, AND the technical implementation. Confluence holds text plus links; large or binary assets live in Google Drive.

## When to use

- Use after implementation is complete and you are in the POST cycle.
- Use when you need a durable, human-readable record of the work that combines the original ask, the narrative, the acceptance criteria, and what was actually built.
- Run this before delivery-post-jira-link (it links the Jira ticket to the page you create here) and alongside delivery-post-changelog.
- Do not use to capture requirements up front — that is delivery-pre-requirements.

## How it works

1. Confirm the Atlassian connection is ready. If not, run delivery-connect first.
2. Gather inputs: the requirements artifacts from delivery-pre-requirements (the original ask, the story/narrative, acceptance criteria) and the technical reality of the implementation (what changed, key decisions, how it works). Reuse the dev workflow's in-repo `/docs` from dev-start as the technical source, but expand it with the story context.
3. Decide create vs. update: search Confluence for an existing page for this story. Update it if present; otherwise create a new page in the correct space, under a sensible parent.
4. Write the page so a human can read it top to bottom. Include, at minimum:
   - The original ask — what was requested and by whom.
   - The story / narrative — the why, the user need, the journey (not just a task list).
   - Acceptance criteria — and whether each was met.
   - Technical implementation — what was built, key decisions, how it works, where the code lives.
   - Links — to the Jira ticket(s), the changelog, and any Drive assets.
5. For any large or binary asset (images, diagrams, exports, datasets, attachments), do NOT attach it to Confluence. Hand it to delivery-drive-archive to upload to Google Drive, then embed the returned shareable link in the page. Respect the ~2 GB Atlassian cap — Confluence stores text plus links only.
6. Create or update the page via the Atlassian MCP server (Confluence create/update page capability). Capture the resulting page URL/ID for hand-off.

## Hand-off / next

- Pass the page URL/ID to delivery-post-jira-link to link it onto the required Jira issue(s).
- Coordinate with delivery-post-changelog so the changelog and this page cross-reference each other.
- If you produced large assets, ensure delivery-drive-archive ran and its Drive links are embedded before declaring done.

## Notes

- Refer to MCP capabilities (create/update a Confluence page), not exact tool function names.
- The defining rule: technical detail alone is not enough — the page must carry the original ask and the story, or it is incomplete.
- Never paste large or binary content inline; link to Drive. Honor the ~2 GB Atlassian cap.
- Prefer updating an existing story page over creating duplicates.
