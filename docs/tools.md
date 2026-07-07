# Tool adapters

`tools/<tool>/README.md` are thin adapters: each explains *where a given AI
tool expects the generic `agents/` content to be copied to*. Adapters hold no
original content of their own — the contribution convention explicitly
forbids storing content in `tools/` (`agents/README.md`); they exist purely
for wiring, and are edited only when a tool needs new wiring.

## Status

| Tool | Path | Status |
|---|---|---|
| Claude Code | `tools/claude/README.md` | Complete |
| Gemini CLI | `tools/gemini/README.md` | Partial — 2 open `_TODO`s |
| Google Antigravity | `tools/antigravity/README.md` | Partial — 2 open `_TODO`s |

## Claude Code (complete)

- **Instructions:** `agents/AGENTS.md` + the chosen `workflows/<wf>/AGENTS.md`
  and `stacks/<tech>/AGENTS.md` combine into `CLAUDE.md` (project: `./CLAUDE.md`
  or `./.claude/CLAUDE.md`; personal: `~/.claude/CLAUDE.md`). An optional
  Unix-only path uses `@`-imports inside `CLAUDE.md` instead of pasting content
  verbatim.
- **Skills:** copy a skill directory to `.claude/skills/<name>/SKILL.md`
  (project) or `~/.claude/skills/<name>/SKILL.md` (personal); the generic
  frontmatter (`name`, `description`) is already in Claude's expected format.
  Single-file commands also work as `.claude/commands/<name>.md`.
  `claude --add-dir <path-to-agentic>` auto-loads this repo's
  `.claude/skills/` for a session without copying, but is per-invocation and
  Claude-only — copy-paste remains the durable path.
- **Models:** Claude Code reads only the single `model:` value
  (`opus`/`sonnet`/`haiku`/`inherit`) and **ignores `model-fallback:`
  entirely** — it has no Gemini path. If the primary model is unavailable, the
  fallback chain must be actioned manually. The adapter flags that
  `model-fallback:` relies on Claude Code silently ignoring unknown
  frontmatter keys (standard YAML behavior, not explicitly documented) — if
  that ever causes a load issue, the adapter's fallback is to demote the key
  to a comment: `model: opus  # fallback: sonnet, gemini-pro`.

## Gemini CLI (partial)

- **Instructions:** `agents/AGENTS.md` + chosen workflow/stack `AGENTS.md`
  combine into a project's `GEMINI.md`.
- **Skills:** _open — Gemini's exact command/skill location and frontmatter
  format is unverified; the adapter has not documented a copy-paste target
  yet._
- **Models:** Gemini is the cross-vendor backstop at the end of every
  `model-fallback:` chain — `opus`/`sonnet` skills fall through to
  `gemini-pro` since the Anthropic tiers don't exist in this tool.
  _Open: Gemini's exact model identifier/alias for `gemini-pro` and how to pin
  it per skill are unconfirmed._

## Google Antigravity (partial)

- **Instructions:** _open — the instruction file's name and location are
  unverified; no copy-paste target for `agents/AGENTS.md` + chosen layers has
  been documented yet._
- **Skills:** _open — the command/skill format and location are unverified;
  no copy-paste target has been documented yet._
- **Models:** not yet addressed by the adapter.

## Closing these gaps

Per the contribution convention, closing a `tools/gemini` or
`tools/antigravity` `_TODO` means verifying the real tool behavior and editing
that adapter file only — never adding Gemini/Antigravity-specific content into
`agents/`, which must stay tool-agnostic.
