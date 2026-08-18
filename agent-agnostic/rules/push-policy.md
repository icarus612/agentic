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
- **Pushing**: Builder agents should never push. The `push-pr` skill is the sole publisher across the whole run: it opens the PR as a draft right after plan approval, pushes the parent branch again after every lane merge-back and record commit, and flips the PR from draft to ready at the end.
- **Permissions**: A conversational confirmation is required before `push-pr --stage open-draft` and `push-pr --stage finalize` — the two outward-facing PR-state changes (opening the draft PR, marking it ready). `push-pr --stage update`, run as part of a lane merge-back or the record commit, asks nothing conversationally: the user's approval at the plan gate already authorizes it. That carve-out is scoped exactly to the run's own parent branch through `push-pr --stage update` — every other push, in every other context, still requires explicit confirmation first, and none of this is autonomous or silent.
- **Force-push**: Force-pushing in any form is strictly forbidden.
