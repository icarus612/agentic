# Confluence — stack instructions

Bound to the Confluence/Atlassian service (`domain: confluence`). Installs into projects that
publish docs to a wiki, never into `~/.claude/`.

**Publication is one-way, repo → Confluence.** The local docs tree under the resolved
`CLAUDE_DOCS_DIR` is the single source of truth; the published copy is downstream output. An edit
made in Confluence is not a source change — it is overwritten by the next sync. Nothing here may
describe the published copy as canonical. Why: `review-pr` judges the branch diff, and docs that
lived only in Confluence would not be in it.

**The sync is a CI job on merge, not a run stage.** No dae run publishes to Confluence.

## Contents

| Path | What it is |
|---|---|
| `rules/external-storage-cap.md` | always-on while this tech is in play — caps what may be pushed to external storage, and offloads large attachments rather than inlining them |
| `skills/document-confluence/` | manual/recovery sync, for when CI has not run or has failed — never an author, never a source of truth, and no run dispatches to it |
| `ci/` | shipped CI reference for consuming projects |

## Configuration

The publish target resolves through `CLAUDE_DOCS_PUBLISH` (unset by default — unset means record
locally and stop). It accepts an Atlassian wiki URL or the `confluence:<SPACE>[/<Parent Page>]`
shorthand; the `confluence:` scheme is what selects `document-confluence`. The docs root resolves
separately through `CLAUDE_DOCS_DIR`, which is `--expect path`-enforced and must always be a local
path — see the `artifact-locations` rule for both chains.
