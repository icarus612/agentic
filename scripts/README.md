# scripts/

This directory currently holds one entry: `publish-docs.yml`, a **symlink**
to `../.github/workflows/publish-docs.yml`.

## Why the symlink points "backwards" into `.github/`

The instinct on seeing a symlink between a workflow's conventional location
and a `scripts/` directory is to assume the real file lives in `scripts/`
and `.github/` holds the pointer. That is backwards here, and deliberately
so — do not "fix" it.

- **The git mechanism.** Git stores a symlink as a blob whose *content is
  the target path string*, at file mode `120000`. If the real file lived
  in `scripts/` and `.github/workflows/publish-docs.yml` were the symlink,
  a consumer reading that `.github` path through git — which is exactly
  what GitHub Actions does when parsing workflows — would receive the
  literal text `../../scripts/publish-docs.yml`, not YAML.
- **The GitHub limitation.** GitHub Actions does not resolve symbolic
  links when parsing files under `.github/workflows/`; a symlink at that
  path fails CI immediately. This is a known, open feature request
  ([community discussion #109744](https://github.com/orgs/community/discussions/109744)),
  not a supported pattern.

So the direction is inverted from the naive expectation: the **canonical,
real file lives in `.github/workflows/publish-docs.yml`**, and
`scripts/publish-docs.yml` is the symlink — a readable surface for anyone
browsing `scripts/` for tooling. `cat scripts/publish-docs.yml` resolves
through the link and prints the workflow YAML; there is still exactly one
file, not two copies to keep in sync.

## Editing the trigger for a different project

The workflow's branch list and path filter (`on: push: branches: paths:`)
are static YAML — GitHub cannot evaluate a resolved `CLAUDE_DOCS_DIR` or
base-branch value at trigger time. A project whose docs root isn't `/docs`,
or whose base branch isn't `main`, edits those two lists directly in
`.github/workflows/publish-docs.yml` (never in the symlink).

## What else belongs here

`scripts/` is a plausible future home for install tooling. It does **not**
currently hold any — in particular, `agent-agnostic/hooks/sync-install.sh`
does not move here. That script is live and load-bearing for this repo's
own push flow (`source-push-sync`) and stays where it is.
