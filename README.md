# agentic

A **library** of AI-agent skills, rules, and hooks — a single source of truth
you install into Claude Code or Google Antigravity. It is **not** a project you run. Nothing here
executes; you copy pieces of it to where the tool expects them.

## The one question

Everything is classified by **what it is bound to** — and that answer also
decides where it installs:

| `domain:` | Bound to | Installs to |
|---|---|---|
| `universal` | nothing — works on any project, any stack | **user level**: `~/.claude/` (Claude) or `~/.gemini/config/` (Antigravity) |
| `<tech>` (`svelte`, `django`, `medusa`, `confluence`, …) | one technology or service | **project level**: that project's `.claude/` / `.agents/` |
| `<project-name>` (`mythic-made`, …) | one project — brand tokens, its own layout | lives only in that project; **never in this repo** |

`domain:` is the only classifier, and it's the only one that survives: the
install target is flat (`skills/<name>/SKILL.md`), so this repo's folders
vanish. Nothing inside a skill or rule may reference this repo's layout.

## Directory map

```
agentic/
├── AGENTS.md                  # the index — read this first
├── orchestrators/             # ENTRY POINTS and WORKERS             (domain: universal)
│   ├── skills/                #   dae (/dae), orchestrate (/orchestrate)
│   ├── hooks/                 #   workflow-setup.sh, workflow-diff-check.sh, resolve-config.sh,
│   │                          #   sync-install.sh, scope-writes.sh, mark-syllabus.sh, verify-scope.sh
│   └── agents/                #   planner.md (+ planner/plan-*.md), builder.md, coder.md, contract-tester.md
├── agent-agnostic/                   # GLOBAL: bound to no technology       (domain: universal)
│   ├── rules/                 #   the always-on set
│   ├── skills/                #   explore, init-workspace, review-*, document-local, push-pr
│   ├── hooks/                 #   smart-lint.sh, smart-test.sh, … (wired via settings.json)
│   └── settings/              #   settings.json — versioned source of ~/.claude/settings.json
├── tool-based/                # bound to ONE technology              (domain: <tech>)
│   └── <tech>/                #   svelte, tailwind, typescript, django, godot, confluence, …
│       ├── rules/
│       └── skills/
├── tests/                     # plan-lifecycle.sh's fixture test    (repo-root, D4)
├── docs/                      # meta-docs about this repo itself
├── .github/                   # workflows/publish-docs.yml — canonical; docs→Confluence CI (no-op here)
└── scripts/                   # publish-docs.yml symlinks → .github/workflows/ (CI templates for consumers)
```

## The dae pipeline

`/dae` routes every request to exactly one workflow — the full type list
lives in [`orchestrators/AGENTS.md`](orchestrators/AGENTS.md) — and drives
two workers through cold gates:

```
planner ‖ init-workspace → review-plan ⇄ (human gate, capped)
   → push-pr --stage open-draft (draft PR opens)
   → builder lanes (each: contract → coder ‖ contract-tester per packet
     → debug-mediated rework → builder's own e2e exit → push-pr --stage update)
   → review-code ⇄ (human gate; kickback codes impl-wrong|plan-wrong|map-wrong)
   → document-local → push-pr --stage update
   → review-pr ⇄ (mandatory gate) → push-pr --stage finalize
```

Coders never see tests; contract-testers never see implementation — the
anti-cheating is structural, not disciplinary. Each builder works in its own
child worktree and merges back into the run's parent branch. Details:
[`orchestrators/AGENTS.md`](orchestrators/AGENTS.md).

## Skills, rules, hooks

- **Skills** — on-demand procedures. Selected by `description` or an explicit
  `/name`, never by folder. Universal forks/gates are invoked by name by an
  orchestrator or worker, so their descriptions say so — that guard is what
  stops single-word skills (`explore`) auto-firing on a stray keyword. Tech
  skills *are* meant to match whenever their tech is in play.
- **Rules** — always-on constraints. Short, no procedure. If it must hold even
  when nothing was invoked, it's a rule.
- **Hooks** — deterministic mechanical enforcement (shell, no model judgment).
  Skill-scoped hooks wire via a skill's `hooks:` frontmatter; global quality
  hooks wire via `settings.json`.

Litmus: *"must always hold"* → rule. *"how to do a job"* → skill. *"must happen
every time, mechanically"* → hook.

## Install

1. Copy `orchestrators/skills/*` and `agent-agnostic/skills/*` (whole directories —
   several carry sibling files and `scripts/`) into `~/.claude/skills/` (or `~/.gemini/config/skills/`),
   `orchestrators/agents/*` into `~/.claude/agents/` (or `~/.gemini/config/agents/`), and `agent-agnostic/rules/*`
   into your `CLAUDE.md` context (or `~/.gemini/config/rules/`).
2. Copy each `tool-based/<tech>/` layer your project uses into that **project's**
   `.claude/` (or `.agents/`).
3. Hooks (`agent-agnostic/hooks/`, `orchestrators/hooks/`) go to `~/.claude/hooks/` (or `~/.gemini/config/hooks/`) —
   automated by Nix home-manager in this setup; copy them manually otherwise.
4. Grant the install standing permission in **`~/.claude/settings.json`** (global,
   not a project file) for Claude Code, or wire up `agent-specific/antigravity/hooks.json` for Antigravity. Copying the payload in is not enough: every `Skill`
   invocation and every read of a skill's sibling modules is permission-checked,
   and the interactive "always allow" button does not persist a `Skill` rule —
   it only fills a session-scoped skill allowlist that dies with the session.

   ```jsonc
   "permissions": {
     "allow": [
       "Skill",                                  // or per-skill: "Skill(dae)", "Skill(planner)", …
       "Read(//home/<you>/.claude/skills/**)",   // sibling modules: dae/build.md, dae/sync.md, …
       "Read(//home/<you>/.claude/rules/**)",
       "Read(//home/<you>/.claude/hooks/**)",
       "Read(//home/<you>/.claude/agents/**)",   // planner type modules: agents/planner/plan-*.md
       "Edit(//home/<you>/<code-root>/**/.workflows/**)"  // workflow worktrees + run dirs
     ],
     "additionalDirectories": [
       "/home/<you>/.claude/skills",
       "/home/<you>/.claude/rules",
       "/home/<you>/.claude/hooks",
       "/home/<you>/.claude/agents"
     ]
   }
   ```

   It must be the **global** settings file. `.claude/settings.local.json` is
   per-project, and an orchestrator run reads these paths from wherever its
   worktree happens to be — a project-scoped grant leaves the same prompt
   waiting in the next project.

   Optionally wire `allow-workflow-cleanup.sh` (installed with the hooks in
   step 3) so lane cleanup stops prompting — it auto-allows only safe
   `git branch -d` of workflow-namespace branches tied to the project's
   workflows dir and plain `git worktree remove` of lane-child worktrees
   (`-l<n>` under the workflows dir; parent worktrees still prompt), and has
   no opinion on anything else:

   ```jsonc
   "hooks": {
     "PreToolUse": [
       {
         "matcher": "Bash",
         "hooks": [
           { "type": "command",
             "command": "~/.claude/hooks/allow-workflow-cleanup.sh",
             "if": "Bash(git branch:*)" },
           { "type": "command",
             "command": "~/.claude/hooks/allow-workflow-cleanup.sh",
             "if": "Bash(git worktree remove:*)" }
         ]
       }
     ]
   }
   ```

Distribution is deliberately copy-paste, not symlinks or a setup script, so it
behaves identically across platforms with zero tooling.
`orchestrators/hooks/sync-install.sh` automates the universal-domain copy for
THIS repo's own working copy to both Claude and Antigravity (accepts `--claude` and `--agy` flags). It is what the repo-local `push-main` skill runs
after every landing, deletions included.

## Contributing

- Edit **here first**, never in `~/.claude/` — that's an install, not the source.
- A skill in THIS repo is bound to nothing (`domain: universal`, goes in
  `orchestrators/` or `agent-agnostic/`) or to exactly one tech (`domain: <tech>`, goes
  in `tool-based/<tech>/`). A third value, `domain: <project-name>`, exists for
  irreducibly project-local content — but that never lives here, only in the
  project itself.
- Every skill declares `description`, `domain`, `model` + `model-fallback`, and
  the `rules:` it depends on.
- Keep rules short — they're always-on context.
- Never let a skill or rule reference this repo's directory layout.
