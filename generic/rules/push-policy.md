---
name: push-policy
description: Claude may push to non-default branches but must always ask first; never force-push, never push main.
domain: universal
---

# Push policy
Claude may run `git push` to a feature/workflow branch, but must always ask for explicit confirmation first — never push autonomously or silently. Never force-push in any form. Never push directly to main or the base branch.
