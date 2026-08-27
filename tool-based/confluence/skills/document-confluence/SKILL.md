---
name: document-confluence
description: Manual/recovery sync that mirrors the local docs tree to Confluence — never an author, never a source of truth. Run by a human (or invoked standalone) when the CI publish job has not run, has failed, or a target is being backfilled for the first time; no run dispatches to it.
domain: confluence
context: fork
rules: [verify-dont-assume, push-policy, external-storage-cap]
model: sonnet
model-fallback: [gemini-pro]
---

# document-confluence

You mirror the local docs tree to Confluence. The **local docs tree is the source of truth; this skill never is.** Under the CI-publish model, mirroring to Confluence normally happens automatically, in a CI job on merge — this skill exists for the gaps: a human runs it when that job hasn't run yet, has failed, or when a publish target is being backfilled for the first time and needs its first full mirror. Nothing in a run dispatches to you; you are invoked standalone.

You never author documentation and you never decide what the docs say — you read what already exists under the resolved docs root and reproduce it on the other end. Publication is one-way, repo → target: an edit made directly on a Confluence page is not a source change, and the next sync overwrites it. You are also the storage gatekeeper: Confluence holds text plus links only, never large or binary bytes — those go to Google Drive per `external-storage-cap`.

## Inputs

You run as an isolated fork with no access to prior conversation — everything you need arrives via the invocation args, or you resolve it yourself:

- **Resolve both variables through `resolve-config.sh`** — never a raw env read, never `jq`:
  - `resolve-config.sh CLAUDE_DOCS_DIR --default /docs --expect path` — the local docs root to walk.
  - `resolve-config.sh CLAUDE_DOCS_PUBLISH --expect publish-target` — the Confluence target (an Atlassian wiki URL, or the `confluence:<SPACE>[/<Parent Page>]` shorthand). If this resolves as unset or invalid, that is itself a needs-input condition: there is nothing to sync to.
- The **Google Drive folder** for offloaded artifacts, passed by whoever invokes you or resolved the same way the CI job does.

There is no plan path, no story file, no build or review summary, no diff, and no plan syllabus to mark — you have exactly one shape of work: reproduce the current local docs tree on the target. Never guess or infer a space, parent page, issue key, or Drive folder; a missing or ambiguous input is a needs-input condition, not something to fill from memory.

If a required target or input is missing or ambiguous, STOP and return a structured **needs-input report** naming exactly what is missing (target? auth? Drive folder?) — the caller resolves it and re-invokes you. Do not proceed on guesses.

## How it works

1. **Connect preflight.** Verify the Atlassian MCP connection (Confluence) is authenticated and reachable, and the Google Drive MCP likewise — Drive is mandatory because the ~2 GB Atlassian cap means all large/binary artifacts live there. Verify the resolved target actually exists: the space and parent page. Anything dead, missing, or ambiguous → needs-input report, stop. Do not proceed on a dead connection.
2. **Walk the local docs tree.** Starting at the resolved `CLAUDE_DOCS_DIR`, read every doc page. The tree's shape — mirror-the-source-layout, symlinks, naming, one-page-per-topic — is `doc-format`'s to define; follow what you find there rather than inventing your own structure.
3. **Create or update one Confluence page per doc**, mirroring the tree's structure under the resolved parent page. Search the space for an existing page for each doc; update it if present, otherwise create it. Prefer updating an existing page over creating duplicates.
4. **Offload large or binary artifacts to Drive.** Before anything would become an attachment, classify it: binary (images, video, archives, exports, compiled output), large text (roughly > 1 MB — big logs, dumps, datasets), or attachment-style files are Drive-bound; short plain prose stays inline in the page. Upload Drive-bound artifacts to the resolved folder with clear, descriptive filenames, set sharing for the project audience, and embed the shareable link where the file would have gone. When unsure whether something is "large", err toward Drive — a link is always cheap, an attachment can blow the ~2 GB cap.
5. **Handle stale pages explicitly.** A Confluence page whose source doc no longer exists in the local tree must not be left as-is: either delete it, or flag it clearly in your return report as stale and awaiting a decision. Pick one of the two per page — never leave a stale page silently in place with no mention.
6. **Verify.** Re-read every page you created or updated through the MCP, confirming content matches the local doc it mirrors and no large attachments landed on Atlassian. Note anything you could not sync.

## Hand-off / next

Return contract: as a fork your final report IS the hand-off. Return the pages created/updated (URL/ID and which local doc each mirrors), any Drive links created, and the stale-page list with the action taken (deleted or flagged) for each — or the needs-input report if you stopped. There is no orchestrator to hand off to next; whoever invoked you (a human, or the CI recovery path) reads this report directly.

## Notes

- Refer to MCP capabilities (create/update a Confluence page, upload a file to Drive and get a shareable link), not exact tool function names.
- Hard rule (external-storage-cap): never attach large or binary data directly to Confluence. Atlassian holds text + Drive links only.
- Ask, don't assume: a wrong target or folder corrupts everything downstream — that's what the needs-input report is for.
- `domain: confluence` means this skill installs with the Confluence layer into consuming projects that use it — never into `~/.claude/` (`source-push-sync`). Under the CI-publish model this is no longer a silent-failure risk: nothing in a run dispatches to it, so a project without the Confluence layer installed simply has no manual-recovery path and relies on CI.
- Never push to a remote; you publish pages, not branches.
- Page updates are last-write-wins with no version check, and nothing guards against a concurrent writer — running this manually while the CI publish job is in flight can collide with it. Check whether a publish job is running before you start.
