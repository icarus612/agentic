# `agents/` — the canonical, tool-agnostic source of truth

Everything in this directory is **generic**. No tool-specific syntax, no
references to a particular agent or IDE. Tools consume this content via the thin
adapters in [`../tools/`](../tools/) — they never copy it back here.

## What lives here

| Path | Type | Contents |
|------|------|----------|
| `AGENTS.md` | — | Index + pointers for this layer. |
| `rules/` | rule | Universal, always-on behavioral rules. |
| `workflows/<wf>/` | workflow | A process: its `AGENTS.md` guide, `rules/`, and `skills/` (`dev`, `delivery`). |
| `stacks/<tech>/` | stack | Tech-specific `AGENTS.md`, `rules/`, and `skills/`. |

Layers compose: **universal ⊕ workflow(s) ⊕ stack(s) ⊕ project**. The project
layer is *not* stored here — it lives in each consuming repo.

## Skill format

One skill per directory: `skills/<name>/SKILL.md`, with frontmatter.

```markdown
---
name: <kebab-name>
description: <when to use this — the agent matches the task against THIS line>
type: <workflow|stack>
domain: <dev|delivery|python|…>          # the subcategory; mirrors the folder
rules: [<rule-name>, …]                  # the rules this skill depends on
model: <opus|sonnet|haiku>               # primary model the skill runs on
model-fallback: [<next>, …]              # ordered backups for tools that support them
---

<the skill body: the procedure the agent should follow>
```

A skill's body is **loaded on demand** — the model reads the `description` to
decide whether to pull it in. That's why the description earns its tokens.

## Rule format

One rule per file: `rules/<name>.md`. Rules are **always-on context**, so they
stay short and frontmatter-light (no `model`, no body-gating `description`-as-
selector — there's no selection step for an always-loaded rule).

```markdown
---
name: <kebab-name>
description: <one-line summary, for humans + adapters>
type: rule
domain: <universal|dev|delivery|…>       # mirrors the folder
---

# <Rule title>
<the rule, in a sentence or two>
```

## Type, domain & folders

`type:` is **`workflow`**, **`stack`**, or **`rule`**; `domain:` is the
subcategory and mirrors the folder (`workflows/dev` → `domain: dev`,
`stacks/python` → `domain: python`, `rules/` → `domain: universal`). An agent
doesn't choose a skill by its folder — it matches the `description` (or you invoke
it by name). Folders exist for **composition** and **maintenance**.

## Model policy

Each skill names the model it should run on, plus an ordered fallback chain:

- **`model:`** — the primary model. Anthropic-first: `opus` for high-leverage
  skills (orchestration, planning), `sonnet` for the rest.
- **`model-fallback:`** — ordered backups used when the primary is unavailable,
  ending in `gemini-pro` as a cross-vendor backstop.

So orchestration/planning skills (`dev-start`, `dev-plan`, `delivery-start`)
resolve **opus → sonnet → gemini-pro**; everything else **sonnet → gemini-pro**.

This chain is **declarative intent**. Each tool honors as much as it can: Claude
Code reads `model:` (a single Anthropic value) and ignores the rest — it has no
Gemini path; a Gemini-capable tool or a multi-provider router can walk the whole
chain. (The full policy is itself a rule: [`rules/model-policy.md`](rules/model-policy.md).)
See the per-tool adapters in [`../tools/`](../tools/).
