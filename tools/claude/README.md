# Claude Code adapter

How to consume the generic content in [`../../agents/`](../../agents/) from
Claude Code. This is an **adapter** — it tells you where Claude expects files. The
content itself always lives in `agents/`; you copy it into place.

> **Method: copy-paste.** Download/clone this repo and copy the pieces you want
> into your project. No script, no symlinks — deliberately, so it works the same
> on Linux, macOS, and Windows.

## Instructions (`AGENTS.md` → `CLAUDE.md`)

Claude Code reads `CLAUDE.md`, not `AGENTS.md`. Copy the global instructions, plus
any stack layers you need, into your project's `CLAUDE.md`:

- Project-wide: `./CLAUDE.md` or `./.claude/CLAUDE.md`
- Personal/global: `~/.claude/CLAUDE.md`

Combine `agents/global/AGENTS.md` + `agents/stacks/<tech>/AGENTS.md` into that
file.

**Optional (unix, advanced):** instead of pasting, import by reference inside your
`CLAUDE.md`:

```markdown
@~/repos/agentic/agents/global/AGENTS.md
@~/repos/agentic/agents/stacks/python/generic/AGENTS.md

# project-specific additions below
```

## Skills

Copy a skill directory into Claude's skills location:

- Project: `.claude/skills/<name>/SKILL.md`
- Personal/global: `~/.claude/skills/<name>/SKILL.md`

The generic `SKILL.md` frontmatter (`name`, `description`) is already in the
format Claude expects. Simple single-file commands also work as
`.claude/commands/<name>.md`.

**Optional:** `claude --add-dir ~/repos/agentic` auto-loads this repo's
`.claude/skills/` for a session — no copying — but it's per-invocation and
Claude-only, so copy-paste is the durable path.

## Models

Each skill declares `model:` plus an ordered `model-fallback:` (see
[`../../agents/README.md`](../../agents/README.md#model-policy)). Claude Code
honors **only** the single `model:` value, and only Anthropic aliases
(`opus`/`sonnet`/`haiku`/`inherit`):

- Claude Code reads `model:` (e.g. `opus` for `begin`/`plan`, `sonnet` for the
  rest) and **ignores `model-fallback:`** — it has no Gemini path and no
  fallback-chain syntax. If the primary is unavailable you switch manually.
- The `model-fallback: [… , gemini-pro]` line is inert here; it exists for
  Gemini-capable tools and multi-provider routers.

> Note: `model:` is verified-supported in skill/command frontmatter. The custom
> `model-fallback:` key relies on Claude Code ignoring unknown frontmatter keys
> (standard YAML behavior, but not explicitly documented). If it ever causes a
> load issue, demote it to a comment: `model: opus  # fallback: sonnet, gemini-pro`.
