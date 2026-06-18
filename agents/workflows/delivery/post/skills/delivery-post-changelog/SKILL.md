---
name: delivery-post-changelog
description: Promote dev's local docs/changelog into a Confluence changelog page for this change, linking the story page and Jira ticket(s)
type: workflow
domain: delivery
rules: [never-push, external-storage-cap]
model: sonnet
model-fallback: [gemini-pro]
---

# delivery-post-changelog

POST cycle. After implementation is done and the main story page is published, promote the change into a **Confluence changelog page** so the team keeps a running history of what changed and why. The entry is short, human-readable, and points to the fuller story page and the Jira ticket(s).

The repo's technical docs stay local — `dev-document` keeps `/docs` as the single source of truth and may have written a local `docs/changelog`. The **Confluence changelog is the team-facing history**: this skill reads any local `docs/changelog` left by `dev-document` and mirrors entries that aren't in Confluence yet, so the local file and the Confluence page don't drift. The local file remains a dev artifact; Confluence is the published, linkable record.

## When to use

- After `delivery-post-confluence` has published or updated the main story page for this change.
- When you need a chronological record of changes in the project's Confluence changelog page or space.
- Any time a shippable change lands and the team expects a "what changed, when, and why" trail.

## How it works

1. Confirm connection. Ensure the Atlassian MCP server is authenticated and you know the target space/page (see `delivery-connect`). If not yet connected, run `delivery-connect` first.
2. Locate the changelog target. Find the project's changelog page (or changelog space). If none exists, create a single "Changelog" page in the project space to hold dated entries.
3. Read the local changelog. Check for a local `docs/changelog` (or the docs root set in `docs/AGENTS.md`) written by `dev-document`. If it exists, read it — these dated entries are the authoritative record of what shipped. Compare against the entries already on the Confluence changelog page (match by date + summary) to find which local entries have not been promoted yet.
4. Gather the facts. For the current change, combine the local changelog entry (if any) with the "why"/narrative and acceptance outcomes from the requirements captured in `delivery-pre-requirements` and the implementation done under `dev-start`. If there is no local changelog, synthesize the entry from those sources directly.
5. Write the entry. Migrate every un-promoted local entry to Confluence (newest first), and add the entry for the current change at the top. Do not duplicate entries already present. Keep each to a few lines:
   - Date (use today's date).
   - One-line summary of what changed.
   - A short "why" — the user need or story driver, not just the task.
   - Status (shipped, partial, reverted, etc.).
6. Add the links. In the entry, link to the main story page from `delivery-post-confluence` and to the relevant Jira ticket(s). Do not duplicate the full technical detail here — the story page is the source of truth.
7. Respect the 2 GB cap. The changelog is text plus links only. Never attach images, exports, datasets, or other large/binary artifacts to the changelog. Those belong in Google Drive via `delivery-drive-archive`; reference them with the Drive shareable links already recorded on the story page.
8. Save and verify. Create/update the changelog page via the Confluence capability of the Atlassian MCP server and confirm the new entry renders with working links. The local `docs/changelog` stays in place as the canonical local artifact.

## Hand-off / next

- After the changelog entry is live, run `delivery-post-jira-link` to ensure the Jira ticket(s) reference both the story page and this changelog entry.
- If you discover a large artifact still missing from Drive, hand off to `delivery-drive-archive`, then add its link to the story page (not the changelog).

## Notes

- Keep entries terse and scannable; the changelog is an index, the story page is the detail.
- Always include both links (story page + Jira) so readers can navigate either way.
- Newest entry on top keeps the running history readable over time.
- If the project has no changelog page yet, create exactly one and reuse it for future entries — do not scatter entries across pages.
