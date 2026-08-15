---
name: push-policy
description: Claude must strictly follow the enterprise standard — branch from dev, PR to dev, squash always. Builder agents never push.
domain: universal
---

# Push policy

The global enterprise standard dictates that all work revolves around the `dev` branch:

- **Integration Branch**: `dev` is the universal integration branch. You must ALWAYS branch from `dev` and open remote PRs (GitHub) into `dev`.
- **Squash Only**: PRs into `dev` must always be squash-merged.
- **No Direct Commits**: Never commit or write-tool edit directly on `dev`. Always use a branch.
- **Pushing**: Builder agents should never push. Only the final ship skill (`push-pr`) pushes the workflow branch and opens the PR.
- **Permissions**: Every `git push` still requires explicit confirmation first — never push autonomously or silently.
- **Force-push**: Force-pushing in any form is strictly forbidden.
