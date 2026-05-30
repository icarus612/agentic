# `agents/` — the canonical, tool-agnostic source of truth

Everything in this directory is **generic**. No tool-specific syntax, no
references to a particular agent or IDE. Tools consume this content via the thin
adapters in [`../tools/`](../tools/) — they never copy it back here.

## What lives here

| Path | Scope | Contents |
|------|-------|----------|
| `global/AGENTS.md` | global | Universal conventions + the workflow-skill guide. |
| `global/skills/` | global | Tech-agnostic workflow skills (explore, plan, …). |
| `stacks/<tech>/` | stack | Tech-specific `AGENTS.md` + `skills/`. |

Every scope folder has the same shape: an `AGENTS.md` plus a `skills/` dir.
`global/` and each stack leaf are identical in structure.

Layers compose: **global ⊕ stack(s) ⊕ project**. The project layer is *not*
stored here — it lives in each consuming repo.

## `AGENTS.md` files

`AGENTS.md` is the open, cross-tool instruction-file convention (many agents read
or import it directly). One per scope: the global one here, plus one inside each
stack leaf. Keep them tool-neutral.

## Skill format

One skill per directory: `skills/<name>/SKILL.md`, with frontmatter.

```markdown
---
name: <kebab-name>
description: <when to use this — the agent matches the task against THIS line>
domain: <testing|deploy|lint|docs|...>   # optional browse/filter tag
model: <opus|sonnet|haiku>               # primary model the skill runs on
model-fallback: [<next>, …]              # ordered backups for tools that support them
---

<the skill body: the procedure the agent should follow>
```

## Model policy

Each skill names the model it should run on, plus an ordered fallback chain:

- **`model:`** — the primary model. Anthropic-first: `opus` for high-leverage
  skills (orchestration, planning), `sonnet` for the rest.
- **`model-fallback:`** — ordered backups used when the primary is unavailable,
  ending in `gemini-pro` as a cross-vendor backstop.

So the global workflow skills resolve as **opus → sonnet → gemini-pro** (`begin`,
`plan`) or **sonnet → gemini-pro** (everything else).

This chain is **declarative intent**. Each tool honors as much as it can: Claude
Code reads `model:` (a single Anthropic value) and ignores the rest — it has no
Gemini path; a Gemini-capable tool or a multi-provider router can walk the whole
chain. See the per-tool adapters in [`../tools/`](../tools/).

## Why tech is the folder axis and domain is a tag

An agent does **not** pick a skill by its folder. It matches the `description`
(or you invoke it explicitly by name). So folders aren't for agent selection —
they're for:

- **Composition** — when you set up a Python repo you copy `global + python` and
  get *every* Python-relevant skill in one go.
- **Maintenance** — no agonizing over "is this `testing/` or `python/`?".

Tech is the hard relevance gate (`pytest` is useless in a Go repo), so it's the
folder. The conceptual grouping you'd browse by (testing, deploy, …) lives in the
`domain` frontmatter tag instead. You get both, and never have to choose.
