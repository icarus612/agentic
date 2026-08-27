# Publishing docs to Confluence — CI contract

Publishing the local docs tree to Confluence is a **CI job on merge**, not
a run stage and not something any agent dispatches to. This directory
documents the contract that job implements. It is a prose reference, not a
copy of the workflow — a symlink here would ship to a consuming project as
a blob containing a path (`../../../.github/workflows/publish-docs.yml`)
that either doesn't exist in that project or, worse, resolves onto some
unrelated file it already has at that location. A dangling or
mis-resolving symlink is a live hazard, not a stale copy; prose can't drift
into a wrong file the way a copy or a symlink can.

## The canonical implementation

The agentic repo's concrete implementation of this contract is
`.github/workflows/publish-docs.yml` (surfaced for browsing, not
duplicated, via the symlink at `scripts/publish-docs.yml` — see
`scripts/README.md` for why that symlink points the direction it does). A
consuming project adopting this pattern **copies that file** into its own
`.github/workflows/`, then edits the trigger's branch list and path filter
to match its own base branch and `CLAUDE_DOCS_DIR`.

## The contract, platform-neutrally

GitHub Actions is the concrete form here only because this repo's tooling
already assumes GitHub — `push-pr`, `review-pr`, and `comment-pr` all drive
`gh`. **CI platform is not the Confluence axis**: any CI system that can
run a shell step on merge and hold secrets can implement this. The
contract itself:

- **Trigger.** On merge to the base branch, path-filtered to the docs
  root.
- **Resolve.** `CLAUDE_DOCS_PUBLISH` (`--expect publish-target`) and
  `CLAUDE_DOCS_DIR` (`--expect path`), both through `resolve-config.sh` —
  never a raw env-var read, never `jq`.
- **No-op.** An unset publish target is a graceful no-op: exit 0 with an
  explanatory message. Not an error, not a warning.
- **Mirror.** One Confluence page per doc, structure preserved; large or
  binary artifacts offloaded to Google Drive per `external-storage-cap`;
  stale pages (source doc deleted from the tree) removed or flagged, never
  left silently.
- **Failure.** Auth or target errors fail loudly — non-zero exit, a real
  message. The job never gates the merge, because it runs *after* the
  merge has already happened: a red run reports a problem, it does not
  block or revert anything.

## Direction

Publication is **one-way, repo → target**. The local docs tree is the
source of truth in every configuration. Confluence is read-only for
humans; an edit made there directly is not a source change and is
overwritten by the next sync.

## Required secrets

Supplied by the consuming project's own CI secret store — never committed,
never defaulted anywhere in the workflow or in this contract:

| secret | what it is |
|---|---|
| `ATLASSIAN_USER_EMAIL` | the account the API token belongs to |
| `ATLASSIAN_API_TOKEN` | Atlassian API token with write access to the target space |
| `GOOGLE_DRIVE_CREDENTIALS` | service-account JSON for Drive offload |
| `GOOGLE_DRIVE_FOLDER_ID` | destination folder for offloaded artifacts |

The Confluence site and space are not secrets in this table — they come
from `CLAUDE_DOCS_PUBLISH`, resolved at run time.

## When CI hasn't run

If CI hasn't run yet, has failed, or a target is being backfilled for the
first time, use the `document-confluence` skill to sync by hand. That path
is manual/recovery only — see the skill for how it works.
