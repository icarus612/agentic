# `delivery` workflow

Canonical guide: [`agents/workflows/delivery/AGENTS.md`](../../agents/workflows/delivery/AGENTS.md).
This page is the meta-summary; edit the pipeline behavior in the payload file
above, not here.

Wraps the [`dev`](dev.md) workflow with project documentation in **Atlassian
(Jira + Confluence) and Google Drive**. Where `dev-document` writes *technical*
docs into the repo's `/docs`, `delivery` captures the **story** — the original
ask, the why, the user journey — alongside the implementation, and publishes
it to Confluence with the work linked to its Jira tickets.

```
              ┌──────────── shared ────────────────┐
              │  delivery-start (orchestrator)      │
              │  delivery-connect (Jira/Conf/Drive) │
              │  delivery-drive-archive (offload)   │
              └─────────────────────────────────────┘
   pre ──────────────▶   [ dev workflow ]   ──────────────▶ post
 delivery-pre-requirements   (dev-start)      delivery-post-confluence
 (ask + story + criteria)                     delivery-post-changelog
                                              delivery-post-jira-link
```

Seven skills total, one delivery-scoped rule
(`agents/workflows/delivery/rules/external-storage-cap.md`), no delivery-scoped
hooks.

## Skills

| Skill | Model | Cycle | Role |
|---|---|---|---|
| `delivery-start` | opus → sonnet → gemini-pro | shared (orchestrator) | Runs `delivery-connect` → `delivery-pre-requirements` → hands implementation to **`dev-start`** → runs the POST cycle. Stays on Opus, delegates to Sonnet, surfaces only blockers/summaries. |
| `delivery-connect` | sonnet → gemini-pro | shared | Verifies the Atlassian (Jira+Confluence) and Google Drive MCP connections and resolves the concrete targets every other skill writes to: Confluence space + parent page, Jira project + issue key(s), Drive folder. Asks the user rather than assuming any target. |
| `delivery-drive-archive` | sonnet → gemini-pro | shared | Uploads large/binary artifacts (images, exports, datasets, logs, PDFs, anything binary or roughly >1 MB) to the resolved Drive folder and returns a shareable link for the caller to embed as text. Callable from any step. |
| `delivery-pre-requirements` | sonnet → gemini-pro | pre | Before any code: captures the original ask **verbatim**, the story/narrative (who/why/journey), acceptance criteria, constraints, and stakeholders; identifies or creates the governing Jira ticket(s). Produces a single structured, text-only requirements artifact, verified section-by-section with the user before it's marked ready. |
| `delivery-post-confluence` | sonnet → gemini-pro | post | Creates/updates the Confluence page: original ask + story/narrative (reused from `delivery-pre-requirements`) **and** the technical implementation (reused from dev's `/docs`, expanded with story context). Routes any large/binary asset through `delivery-drive-archive` first. |
| `delivery-post-changelog` | sonnet → gemini-pro | post | Promotes dev's local `docs/changelog` (written by `dev-document`) into a team-facing Confluence changelog page — mirrors any entries not yet promoted, newest first, each linking back to the story page and Jira ticket(s). The local file stays canonical; this is the published mirror. |
| `delivery-post-jira-link` | sonnet → gemini-pro | post | Final POST step: links the Confluence page(s)/changelog onto the Jira issue(s) bidirectionally, updates issue status/fields, never guesses issue keys. |

## Key rules

- **Atlassian + Drive connectors.** Jira/Confluence via the Atlassian MCP;
  files via the Google Drive MCP.
- **`external-storage-cap`** (delivery-scoped rule): Atlassian storage is
  capped around 2 GB. Large/binary artifacts go to Google Drive; Confluence
  and Jira hold text + Drive links only — never direct attachments. Enforced
  by name in `delivery-connect`, `delivery-drive-archive`,
  `delivery-post-confluence`, `delivery-post-changelog`, and
  `delivery-post-jira-link`.
- **Story, not just tasks.** The defining difference from plain `dev-document`
  output: Confluence content must include the technical implementation **and**
  the original ask + narrative (who/why/journey), not a task list alone.

## Relationship to `dev`

`delivery-start` embeds the **entire `dev` pipeline** as its "implementation"
step (`delivery-pre-requirements` → `dev-start` → `delivery-post-confluence`).
`dev`'s own `/docs` output stays the canonical, local, technical source of
truth; `delivery` never duplicates it — it references and republishes on top
(story context, Jira linkage, external storage). Purely technical, in-repo
work with no Atlassian/Drive requirement should invoke `dev-start` directly,
per `delivery-start`'s own "When to use" guidance.
