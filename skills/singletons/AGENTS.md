# Singletons

Standalone skills that are not part of a multi-skill workflow and are not tied to
a stack. Each is a single `SKILL.md` selected by its `description` (or invoked by
name), loaded on demand like any skill.

Use this layer for a self-contained capability that doesn't belong to a process
pipeline (`workflows/`) or a technology (`stacks/`).

Skills:
- **orchestrate** ([`orchestrate/SKILL.md`](orchestrate/SKILL.md)) — turn the
  agent into a pure orchestrator: decompose a multi-part task, delegate each
  subtask to a subagent (parallel where independent), verify and synthesize,
  keep the coordinator's context clean. Runs on `opus` per the model policy.
