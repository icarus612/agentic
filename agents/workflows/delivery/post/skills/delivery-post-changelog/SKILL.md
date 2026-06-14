---
name: delivery-post-changelog
description: Record a dated changelog entry in Confluence for this change, linking the story page and Jira ticket(s)
type: workflow
domain: delivery
rules: [never-push, external-storage-cap]
model: sonnet
model-fallback: [gemini-pro]
---

# delivery-post-changelog

POST cycle. After implementation is done and the main story page is published, append a dated changelog entry so the project keeps a running history of what changed and why. The entry is short, human-readable, and points to the fuller story page and the Jira ticket(s).

## When to use

- After `delivery-post-confluence` has published or updated the main story page for this change.
- When you need a chronological record of changes in the project's Confluence changelog page or space.
- Any time a shippable change lands and the team expects a "what changed, when, and why" trail.

## How it works

1. Confirm connection. Ensure the Atlassian MCP server is authenticated and you know the target space/page (see `delivery-connect`). If not yet connected, run `delivery-connect` first.
2. Locate the changelog target. Find the project's changelog page (or changelog space). If none exists, create a single "Changelog" page in the project space to hold dated entries.
3. Gather the facts. Pull the change summary, the "why"/narrative, and acceptance outcomes from the requirements captured in `delivery-pre-requirements` and the implementation done under `dev-start`.
4. Write the entry. Add a new dated entry (newest first) at the top of the changelog. Keep it to a few lines:
   - Date (use today's date).
   - One-line summary of what changed.
   - A short "why" — the user need or story driver, not just the task.
   - Status (shipped, partial, reverted, etc.).
5. Add the links. In the entry, link to the main story page from `delivery-post-confluence` and to the relevant Jira ticket(s). Do not duplicate the full technical detail here — the story page is the source of truth.
6. Respect the 2 GB cap. The changelog is text plus links only. Never attach images, exports, datasets, or other large/binary artifacts to the changelog. Those belong in Google Drive via `delivery-drive-archive`; reference them with the Drive shareable links already recorded on the story page.
7. Save and verify. Create/update the changelog page via the Confluence capability of the Atlassian MCP server and confirm the new entry renders with working links.

## Hand-off / next

- After the changelog entry is live, run `delivery-post-jira-link` to ensure the Jira ticket(s) reference both the story page and this changelog entry.
- If you discover a large artifact still missing from Drive, hand off to `delivery-drive-archive`, then add its link to the story page (not the changelog).

## Notes

- Keep entries terse and scannable; the changelog is an index, the story page is the detail.
- Always include both links (story page + Jira) so readers can navigate either way.
- Newest entry on top keeps the running history readable over time.
- If the project has no changelog page yet, create exactly one and reuse it for future entries — do not scatter entries across pages.
