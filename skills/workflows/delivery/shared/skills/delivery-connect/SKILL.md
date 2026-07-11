---
name: delivery-connect
description: Verify Atlassian (Jira + Confluence) and Google Drive MCP connections and resolve the work targets for this story.
type: workflow
domain: delivery
rules: [verify-dont-assume, external-storage-cap]
model: sonnet
model-fallback: [gemini-pro]
---

Establish and verify the connections this story needs, then resolve the concrete targets every other skill will write to: the Confluence space and parent page, the Jira project and issue key(s), and the Google Drive folder for offloaded artifacts. This is shared plumbing for both the PRE and POST cycles.

## When to use

- At the start of any story cycle, before delivery-pre-requirements (PRE) or delivery-post-confluence / delivery-post-changelog / delivery-post-jira-link (POST).
- Whenever you are unsure that the Atlassian or Google Drive connection is live, or which space/project/folder this work belongs to.
- After delivery-start has framed the work and you need to bind it to real Atlassian + Drive locations.

## How it works

1. Verify the Atlassian MCP connection (Jira + Confluence). If it is not authenticated or reachable, prompt the user to authenticate and stop until it succeeds. Do not proceed on a dead connection.
2. Verify the Google Drive MCP connection. If it is not authenticated or reachable, prompt the user to authenticate and stop until it succeeds. Drive is mandatory because the 2 GB Atlassian cap means all large/binary artifacts live here.
3. Resolve the Confluence target: the space and the parent page under which this story's documentation will be created. If multiple candidates exist or none is obvious, ask the user. Do not assume a default space.
4. Resolve the Jira target: the project and the relevant issue key(s) this work delivers against. If the key(s) are unknown or ambiguous, ask the user for them. Do not invent issue keys.
5. Resolve the Google Drive target: the folder where offloaded artifacts (images, exports, datasets, attachments) will be uploaded so Confluence/Jira can store only text plus shareable links. If no folder is specified, ask the user or confirm creating one; do not silently pick a location.
6. Confirm all resolved targets back to the user in one summary, then output them for downstream skills.

## Hand-off / next

- Output the resolved targets as a compact record the other skills consume: Confluence space + parent page, Jira project + issue key(s), Google Drive folder (and its link/ID).
- PRE cycle: hand off to delivery-pre-requirements to capture the original ask, the narrative/story, and acceptance criteria, then proceed into the dev workflow via dev-start.
- POST cycle: hand off to delivery-post-confluence (publish docs), delivery-post-changelog (publish the changelog), delivery-drive-archive (upload large/binary artifacts to Drive), and delivery-post-jira-link (link the published pages to the Jira issue key(s)).

## Notes

- Refer to MCP capabilities (create/update a Confluence page, link a Jira issue, upload a file to Drive and get a shareable link), not specific tool function names.
- 2 GB CAP: never attach large or binary data directly to Confluence or Jira. Those systems hold text plus links; the bytes go to the resolved Google Drive folder (see delivery-drive-archive).
- Ask, do not assume. A wrong space, project, issue key, or folder corrupts every downstream skill, so resolve ambiguity with the user up front.
- Re-run this skill if a connection drops or the target work item changes mid-cycle.
