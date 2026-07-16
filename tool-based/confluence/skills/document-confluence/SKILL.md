---
name: document-confluence
description: Publish the workflow's documentation to Confluence — a story + technical page, a changelog page, and bidirectional Jira links, offloading large artifacts to Google Drive. Part of the dev workflow, invoked by the dev/map orchestrators when CLAUDE_DOCS_DIR points at a Confluence location.
domain: confluence
context: fork
rules: [verify-dont-assume, push-policy, external-storage-cap]
model: sonnet
model-fallback: [gemini-pro]
---

# document-confluence

You are the documentation phase of the workflow when the project's docs live in Confluence instead of the repo. `CLAUDE_DOCS_DIR` points at a Confluence location, so **Confluence is the SINGLE SOURCE OF TRUTH for documentation** — there is no local `/docs` tree to maintain. After the work passes the `review-code` gate, you publish pages that tell the whole story: WHY the work was done (the original ask and narrative captured by the orchestrator), the acceptance criteria, AND the technical implementation. You also keep the Confluence changelog page current and wire everything to the governing Jira ticket(s). You are the storage gatekeeper too: Confluence and Jira hold text plus links only; the bytes of any large or binary artifact go to Google Drive.

## When to use

- After the `review-code` gate has accepted the changes (change-driven, from the `dev` orchestrator) — never document unreviewed code.
- When the `map` orchestrator hands you a fresh explore map and the docs target is Confluence — a **map-driven**, technical-only run with no story file.
- When the `sync-status` orchestrator hands you a reconciliation report against a plan and/or Jira ticket for already-shipped work — a **reconciliation-driven** run; the work may not have passed a fresh `review-code` gate in this session.
- Only when `CLAUDE_DOCS_DIR` is a Confluence location; when it is a local path (or unset), `document-local` is the documentation phase instead.

## Inputs

You run as an isolated fork with no access to the conversation history — everything you need arrives via the invocation args. Expect:

- The **parsed Confluence target** — space and parent page, derived from `CLAUDE_DOCS_DIR` (an Atlassian wiki URL, or the `confluence:<SPACE>[/<Parent Page>]` shorthand) and resolved by the orchestrator's requirements step.
- The **Jira issue key(s)** and **Google Drive folder** resolved by the orchestrator. Never guess or infer issue keys from branch names, commit messages, or memory; never assume a default space or silently pick a Drive folder.
- **Change-driven**: the plan path in `/project-plans/`, the story file path (`<slug>-MM-DD-YY.story.md` next to the plan — original ask verbatim, narrative, acceptance criteria, constraints, stakeholders), and the build/`review-code` summary.
- **Map-driven** (from the `map` orchestrator): the explore skill's full structured map instead of plan/story/diff — publish the technical map only; skip the story sections.
- **Reconciliation-driven** (from `sync-status`): the plan path (if one exists), the reconciliation report path, and the resolved Jira issue key(s) — resolved by `sync-status` from either a user-supplied key or a sibling story file next to the plan, NEVER guessed by you. The **story file is optional** in this shape (the work may have shipped outside a tracked `dev` run, so none may exist) — if absent, publish without the story/narrative sections rather than inventing one, same as a map-driven run does. The Jira issue key(s) remain MANDATORY regardless — if `sync-status` didn't resolve one and Confluence mode is active, that's a needs-input condition, not something you infer.
- The changelog preference (update the Confluence changelog page, or none).

If a required target or input is missing or ambiguous, STOP and return a structured **needs-input report** naming exactly what is missing (space? parent page? issue key? Drive folder? auth?) — the caller resolves it with the user and re-invokes you. Do not proceed on guesses.

## How it works

1. **Connect preflight.** Verify the Atlassian MCP connection (Jira + Confluence) is authenticated and reachable, and the Google Drive MCP likewise — Drive is mandatory because the ~2 GB Atlassian cap means all large/binary artifacts live there. Verify the passed targets actually exist: the space and parent page, the issue key(s), the Drive folder. Anything dead, missing, or ambiguous → needs-input report, stop. Do not proceed on a dead connection.
2. **Gather the facts.** Read the plan (and mark its syllabus like `document-local` would: check off `- [x]` completed subphases, annotate `- [dropped]` ones), the story file, and the actual diff (`git diff`, `git status`). Document the real, final state of the code, never an aspiration. In a map-driven run the explore map is your ground truth instead. In a **reconciliation-driven** run, treat the reconciliation report as the record of what shipped (not a fresh diff/review-code summary), and mark the plan syllabus per its classification exactly as `document-local` does.
3. **Publish the story + technical page.** Search the space for an existing page for this work; update it if present, otherwise create it under the parent page. Written so a human can read it top to bottom, it includes at minimum:
   - The original ask — what was requested and by whom (verbatim, from the story file).
   - The story / narrative — the why, the user need, the journey (not just a task list).
   - Acceptance criteria — and whether each was met.
   - Technical implementation — what was built, key decisions, how it works, where the code lives.
   - Links — to the Jira ticket(s), the changelog page, and any Drive assets.
   For a reconciliation-driven run, report each acceptance criterion's status as done/partial/dropped/diverged (not just met/unmet), matching the reconciliation report.
   Map-driven runs publish the technical map (stack with MAJOR versions, structure, dependency graph, patterns, conventions) without the story sections. Prefer updating an existing page over creating duplicates; delete or update pages for code that was removed — stale docs are worse than none.
4. **Update the changelog page.** Find the project's Confluence changelog page; if none exists, create exactly ONE in the space and reuse it for future entries. Add the entry for this change at the top (newest first), a few lines each: date, one-line summary, a short "why", status, and links to the story page and Jira ticket(s). The changelog is an index — text plus links only, no attachments, no duplicated technical detail.
5. **Link Jira bidirectionally.** Add the story page (and relevant Drive links) onto each governing issue as a proper remote/linked page — not a bare URL in a comment; add a short summarizing comment if the issue lacks context. Transition the issue and set fields only as the team's workflow expects — do not invent transitions. Confirm the link resolves both ways: the issue shows the page, and the page references the issue key.
6. **Offload large artifacts to Drive (woven through every step).** Before anything would become an attachment, classify it: binary (images, video, archives, exports, compiled output), large text (roughly > 1 MB — big logs, dumps, datasets), or attachment-style files are Drive-bound; short plain prose stays inline. Upload Drive-bound artifacts to the resolved folder with clear, descriptive filenames, set sharing for the project audience, and embed the shareable link where the file would have gone. When unsure whether something is "large", err toward Drive — a link is always cheap, an attachment can blow the ~2 GB cap.
7. **Verify.** Re-read the published page, the changelog entry, and the issue through the MCP: links present and working in both directions, status correct, no large attachments anywhere on Atlassian. Note anything you could not update.

## Hand-off / next

Return contract: as a fork your final report IS the hand-off. Return the story page URL/ID, the changelog page URL and entry outcome, the issue key(s) updated with their new status, and any Drive links created — or the needs-input report if you stopped. The caller (the `dev` or `map` orchestrator) proceeds to `push-pr`. If while documenting you find the code and the requirements can't be reconciled (an acceptance criterion unmet, the implementation incomplete), stop and recommend a loop back — typically to the `review-code` gate or the build loop — rather than papering over it in prose.

## Notes

- Refer to MCP capabilities (create/update a Confluence page, link a Jira issue, transition an issue, upload a file to Drive and get a shareable link), not exact tool function names.
- The defining rule: technical detail alone is not enough — a change-driven page must carry the original ask and the story, or it is incomplete.
- Hard rule (external-storage-cap): never attach large or binary data directly to Confluence or Jira. Atlassian holds text + Drive links only.
- Ask, don't assume: a wrong space, parent page, issue key, or folder corrupts everything downstream — that's what the needs-input report is for.
- Confluence is canonical in this mode. The repo keeps no parallel `/docs`; if one exists from an earlier local mode, flag the divergence in your report instead of silently maintaining both.
- Never push to a remote; you publish pages, not branches — `push-pr` handles git publishing.
