---
name: delivery-post-jira-link
description: Link published Confluence docs and changelog back to the required Jira ticket(s) bidirectionally
type: workflow
domain: delivery
rules: [verify-dont-assume, external-storage-cap]
model: sonnet
model-fallback: [gemini-pro]
---

You close the POST cycle by wiring the published documentation back to the work it describes. The Confluence page(s) and changelog produced earlier in the POST cycle are only useful if anyone tracking the Jira ticket can find them, so you add the links onto the correct issue(s), move the issue along, and make the relationship discoverable from both sides.

## When to use

Use this skill after `delivery-post-confluence` and `delivery-post-changelog` have published the documentation and you have the live Confluence page URL(s). This is the final step of the delivery workflow's POST cycle. Do not start here without confirmed Confluence links to attach.

## How it works

1. **Confirm the target ticket(s).** Pull the exact Jira issue key(s) recorded by `delivery-connect` and `delivery-pre-requirements`. Never guess or infer issue keys from branch names, commit messages, or memory. If the key is ambiguous or missing, stop and resolve it before touching any issue.

2. **Gather the links.** Collect the Confluence page URL from `delivery-post-confluence`, the changelog page/section URL from `delivery-post-changelog`, and any Google Drive shareable links surfaced by `delivery-drive-archive` that belong on the ticket. You are linking text and URLs only — never attach large or binary artifacts to Jira (see the 2 GB cap in Notes).

3. **Add the links onto the issue.** Use the Atlassian MCP server to add the Confluence (and relevant Drive) links to each target issue — prefer a proper remote link / linked Confluence page over a bare URL pasted in a comment, so the relationship is structured. Add a short comment summarizing what was published and why if the issue lacks context.

4. **Update status and fields.** Use the Atlassian MCP to transition the issue and set fields as appropriate for the team's workflow (e.g. move to Done/Documented, set a fix version, fill a documentation field). Only change what the workflow expects; do not invent transitions.

5. **Ensure bidirectional linking.** Confirm the link resolves both ways: the Jira issue shows the Confluence page, and the Confluence page references the issue key (Jira links the issue automatically when the page mentions the key, or add the relationship explicitly via the Atlassian MCP). Both the issue and the page should point at each other.

6. **Verify.** Re-read the issue through the Atlassian MCP and confirm the links are present, the status is correct, and each link opens the intended page. Note any issue keys you could not update.

## Hand-off / next

This completes the POST cycle and the delivery workflow as a whole. Report the updated issue key(s), their new status, and the attached links. If implementation continues, the next change re-enters at `dev-start`, and a new story begins again at `delivery-start`.

## Notes

- 2 GB cap: Atlassian (Jira/Confluence) storage is capped around 2 GB. Large or binary artifacts live in Google Drive (via `delivery-drive-archive`); Jira and Confluence hold only text plus links. Link Drive URLs onto the issue — never upload the files themselves.
- Refer to Atlassian capabilities (link a Jira issue, add a remote link, transition an issue, add a comment) rather than guessing exact MCP tool function names.
- One source of truth for issue keys: `delivery-connect` and `delivery-pre-requirements`. If they disagree or are silent, escalate rather than guess.
- Bidirectionality is the goal of this skill — a one-way link is incomplete.
