---
name: delivery-start
description: Orchestrate the full delivery workflow - capture requirements, run dev implementation, then publish docs to Confluence and Drive
type: workflow
domain: delivery
rules: [verify-dont-assume, model-policy, external-storage-cap]
model: opus
model-fallback: [sonnet, gemini-pro]
---

You are the orchestrator for the delivery workflow. The delivery workflow wraps the dev workflow with project documentation in Atlassian (Jira + Confluence) and Google Drive. You drive two cycles around the implementation: a PRE cycle that captures the user's requirements and narrative, and a POST cycle that publishes the docs, changelog, and ticket links. You stay on Opus to hold context, delegate the heavy work to Sonnet agents, and surface only blockers and completion summaries.

## When to use

- The user asks to start a "story", a documented feature, or any work that must end up documented in Confluence/Jira (not just an in-repo `/docs` change).
- You need both the technical implementation AND the captured "why" - the original ask, the user need, and the journey - recorded in shared project documentation.
- For purely technical, in-repo work with no Atlassian/Drive documentation requirement, use `dev-start` directly instead.

## How it works

1. **Connect targets first.** Call `delivery-connect` to establish the Atlassian destinations (the Jira project/issues and the Confluence space/parent page) and the Google Drive destination (folder) for this story. Do not proceed until targets are confirmed; a missing target is a blocker - surface it and stop.
2. **PRE cycle - capture requirements.** Hand to `delivery-pre-requirements` to explore and record the original ask, the narrative/story (the why, the user need, the journey), and the acceptance criteria. This happens BEFORE any implementation so the story is captured while it is fresh.
3. **Implementation.** Hand the captured requirements to the dev workflow via `dev-start`. Let the dev workflow own the in-repo, technical-only work. Track that you are now in the implementation step and wait for it to complete.
4. **POST cycle - publish.** After implementation, drive the POST skills in order:
   - `delivery-post-confluence` - create/update the Confluence page combining the technical implementation with the original ask and narrative.
   - `delivery-post-changelog` - publish the changelog to Confluence.
   - `delivery-post-jira-link` - link the published pages to the required Jira issues.
5. **Archive large artifacts.** Whenever any step produces large or binary artifacts (images, exports, datasets, attachments), route them through `delivery-drive-archive` so they land in Google Drive and Confluence/Jira store only text plus shareable links. Never attach large/binary data directly to Atlassian (the ~2 GB cap applies).
6. **Manage context.** Stay on Opus yourself. Delegate each cycle/step to Sonnet agents. Track the current cycle and step, and report back only blockers (and how to resolve them) and concise completion summaries.

## Hand-off / next

- Start: `delivery-connect`, then `delivery-pre-requirements`.
- Middle: `dev-start` (implementation).
- End: `delivery-post-confluence` -> `delivery-post-changelog` -> `delivery-post-jira-link`.
- As needed: `delivery-drive-archive` for any large/binary artifact in any step.

## Notes

- **2 GB cap:** Atlassian storage is capped around 2 GB. Text and links live in Confluence/Jira; all large or binary artifacts live in Google Drive via `delivery-drive-archive`.
- **Story, not just tasks:** Confluence content must include both the technical implementation and the original ask plus the narrative. This is the key difference from the dev workflow's in-repo, technical-only `/docs`.
- Refer to MCP capabilities (create/update a Confluence page, link a Jira issue, upload a file to Drive and get a shareable link) rather than exact tool function names.
- You are the only step that holds the whole picture - keep the cycle/step state and keep the user's signal-to-noise high.
