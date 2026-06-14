# Delivery workflow

Wraps the [`dev`](../dev/AGENTS.md) workflow with **project documentation in
Atlassian + Google Drive**. Where `dev-document` writes *technical* docs into the
repo's `/docs`, the delivery workflow captures the **story** — the original ask,
the why, the user journey — alongside the implementation, and publishes it to
Confluence with the work linked to its Jira tickets.

Two cycles plus shared skills:

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

### Key rules

- **Atlassian + Drive connectors.** Jira/Confluence via the Atlassian MCP; files
  via the Google Drive MCP.
- **`external-storage-cap`** ([`rules/`](rules/)) — Atlassian storage is limited.
  Large/binary artifacts go to **Google Drive**; Confluence/Jira hold text + Drive
  links only. Route big artifacts through `delivery-drive-archive`.
- **Story, not just tasks.** Confluence content includes the technical
  implementation **and** the original ask + narrative (who/why/journey).

### When to use each skill

**Shared**
- **`delivery-start`** — orchestrator: runs `delivery-pre-requirements` → hands
  implementation to `dev-start` → runs the post cycle. Calls `delivery-connect`
  first; uses `delivery-drive-archive` for big artifacts. Opus for itself, Sonnet
  workers; surfaces only blockers/summaries.
- **`delivery-connect`** — establish/verify the Atlassian + Drive connections and
  resolve targets: Confluence space + parent page, Jira project + issue key(s),
  Drive folder. Asks when ambiguous.
- **`delivery-drive-archive`** — upload large/binary artifacts to Drive and return
  shareable links, enforcing the storage cap. Used by both cycles.

**Pre cycle**
- **`delivery-pre-requirements`** — before implementation, capture the original
  ask (verbatim), the story/narrative, acceptance criteria, constraints, and
  stakeholders; identify or create the Jira ticket(s). Verify with the user.

**Post cycle**
- **`delivery-post-confluence`** — publish/update the Confluence page(s):
  technical implementation **and** the original ask + story narrative; big assets
  via `delivery-drive-archive`.
- **`delivery-post-changelog`** — record a dated changelog entry in Confluence,
  linked to the main page and the Jira ticket(s).
- **`delivery-post-jira-link`** — link the Confluence docs/changelog to the
  required Jira ticket(s), update status/fields, ensure bidirectional links.

Rules: delivery-scoped rules live in [`rules/`](rules/); universal rules are in
[`../../rules/`](../../rules/). Each skill lists the rules it needs in its
`rules:` frontmatter.
