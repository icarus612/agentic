# Diagnosis — Claude Code regressions from the Antigravity support arc

Ranked candidate-cause report for run `agy-port-claude-regression` (type: **diagnose**).
This report IS the plan. **Promoted at the pick-the-causes gate on 08-15-26** — all twelve
candidates are approved for fix; see Gate decisions below.

## Gate decisions — Round 1, 08-15-26

Four decisions were settled at the human gate. They are binding on the fix lane; the
evidence, root-cause and verified-clean sections below are unchanged from the diagnosis
and remain the justification for each.

1. **Open question RESOLVED — accident, not intent.** `~/.agent-specific/claude/` was an
   accident of `rename.py`. The install root **is and stays `~/.claude/`**, and project-scoped
   config **stays `.claude/`**. No migration to `~/.agent-specific/` will be performed, and
   that directory must not be created. C1–C8 therefore stand as written (they do *not*
   invert). The "Conventions to enforce" section already states this correctly and is the
   normative reference for the fix.
2. **Candidate pick — ALL TWELVE approved (C1–C12).** Single serial lane, executed in the
   suggested fix order (see Skill mapping). Each candidate is tagged `[APPROVED · step N]`
   below, where N is its position in that order.
3. **DP1 RESOLVED — keep the `MultiEdit` widening.** `scope-writes.sh` matching `MultiEdit`
   is ratified as a **deliberate tightening**, not a regression: at baseline a `MultiEdit`
   write outside `CLAUDE_SCOPE_ALLOW` bypassed the anti-cheating gate entirely. **No code
   change is required for this decision** — the current behaviour is the wanted behaviour.
   The fix lane must not revert it, and must not let the prose sweep (C5) describe the gate
   as covering only `Write|Edit|NotebookEdit`.
4. **DP2 RESOLVED — option (b), and C9 is now an approved fix.** Reorder
   `resolve-config.sh`'s chain so **both `~/.claude` entries rank ahead of
   `~/.gemini/config/settings.json`**, so each tool prefers its own config. C9 changes from
   a design question to concrete work.
5. **DP3 RESOLVED — option (b).** The C5 prose sweep is done as a **single full pass over all
   ~25 files**, not split into an executables-first tranche.

## Goal & scope

**In scope.** Determine whether Claude Code still behaves as it did before Antigravity
support landed, on two surfaces the user named:

1. **Repo source** (this worktree) — the hook scripts, rules, skills and agent
   definitions that Claude Code executes and reads.
2. **Machine-local install** (`~/.claude/`) — the live install this machine's Claude
   Code sessions actually load.

**Out of scope.** Antigravity's own runtime correctness (`~/.gemini/config/`), and
whether the Antigravity port achieves its goals. We only ask whether Claude regressed.

**Not done in the diagnosis phase.** No fix was written during investigation, per
`plan-diagnosis`. Post-gate, this file is the spec of record for the fix lane.

## Scope & sources

- **Issue (verbatim from the user):** "here is a writeup from antigravity on changes
  made. please make sure that claude code will still work as intended and as it did a
  few days ago before we started supporting antigravity in this repo. we want to be
  antigravity friendly, but we dont want to regress dae (or any hooks, skills, rules,
  etc) for claude (in agentic and machine local)"
- **Baseline ("working as it did a few days ago"):** `fc097d1`, the parent of `711f1c8`.
- **Suspect ref:** `fc097d1..HEAD` on `main` — five commits (`711f1c8`, `acad713`,
  `276d92c`, `5f4ecc2`, `548fa04`), 68 files, +461/−224.
- **Antigravity's writeup** was treated as a set of unverified claims. Two of its claims
  are confirmed (the four scripts were Claude-hardcoded and were rewritten; the sync did
  run). One claim — that the port was clean — is **contradicted**: see the ranked
  candidates. Its writeup does not mention `711f1c8`'s rename at all, which is where
  every High-ranked candidate below originates.

## Stack & MAJOR versions

Shell-only repo — no package manifest or lockfile exists (`ls` of the repo root:
no `package.json`, `pyproject.toml`, `go.mod`, `Makefile`, `requirements.txt`).
Versions verified by direct invocation on this machine:

| Tool | MAJOR version | Verified from |
|---|---|---|
| GNU bash | 5.1.16(1) | `bash --version` |
| git | 2.34.1 | `git --version` |
| jq | 1.6 | `jq --version` (used only by `claude-install-drift.sh`; every other hook is deliberately jq-free) |
| Python | 3.11.7 | `python3 --version` (only the two one-shot `rename*.py` migration scripts) |

## Conventions to enforce (hard constraints on any fix)

- **The install root on this machine is `~/.claude/`.** `~/.agent-specific/` does not
  exist (`ls -la $HOME/.agent-specific` → *No such file or directory*). Any fix must
  restore `~/.claude/` as the install path and must NOT create `~/.agent-specific/`.
- **The repo-side rename is correct and must be preserved.** `agent-agnostic/`,
  `agent-specific/claude/`, `agent-specific/antigravity/` are the real source dirs.
  A fix must distinguish *repo source paths* (keep) from *install paths* (revert).
- **Project-scoped config is `.claude/` (or the `.agents` symlink to it)**, never
  `.agent-specific/claude/` — `resolve-config.sh:59-61` only ever checks `.agents/`
  and `.claude/`.
- Per `source-push-sync`: edit here, never in `~/.claude/`; land via `push-main`;
  re-run `sync-install.sh` immediately after, or the install stays wrong.
- Hooks are advisory-vs-blocking by exit code; a fix must not change exit-code
  semantics of any hook.

## Reproduction

The core failure reproduces deterministically, and **reproduced itself during this
very investigation**:

```
$ ls /home/icarus64/.agent-specific
ls: cannot access '/home/icarus64/.agent-specific': No such file or directory

$ ~/.agent-specific/claude/hooks/resolve-config.sh CLAUDE_BASE_BRANCH --base-branch-default
bash: /home/icarus64/.agent-specific/claude/hooks/resolve-config.sh: No such file or directory   # exit 127

$ ~/.claude/hooks/resolve-config.sh CLAUDE_BASE_BRANCH --base-branch-default
main                                                                                             # works
```

**Self-demonstrating repro.** This session's planner agent was instructed by its own
installed definition (`~/.claude/agents/planner.md:21`) to load its type module from
`~/.agent-specific/claude/agents/planner/`. The first tool call of this run did exactly
that and failed with exit 2; the module was only found by falling back to the real path
`~/.claude/agents/planner/plan-diagnosis.md`. An agent that trusted the instruction
without probing would have proceeded without its type module.

**False-positive repro** (drift hook, fires on every Write/Edit):

```
$ echo '{"tool_input":{"file_path":"/home/icarus64/repos/agentic/orchestrators/hooks/smart-lint.sh"}}' \
    | ~/.claude/hooks/claude-install-drift.sh
# advisory: "install is now stale" pointing at /home/icarus64/.agent-specific/claude/hooks/smart-lint.sh
# ...even though sync-install.sh --check reports the install is clean.
```

## Root cause (two defect classes, both from `711f1c8`)

`rename.py` produced damage in **both directions** — it rewrote text it should have left
alone, and left text it should have rewritten. Both classes must be fixed; repairing only
one leaves the drift hook broken.

### Class 1 — over-rename (C1, C2, C4, C5, C6, C8, C12)

`rename.py:26-33` (committed at the repo root in `711f1c8`) performs blunt whole-string
substitution over every `.md`, `.sh` and `.json` file:

```python
replacements = [
    ('generic/', 'agent-agnostic/'),
    ('claude/',  'agent-specific/claude/'),
    ...
]
```

The pattern `'claude/'` is unanchored, so besides its intended target it also rewrote
every occurrence of the **install-path convention** `~/.claude/` → `~/.agent-specific/claude/`
and the **project-config convention** `.claude/` → `.agent-specific/claude/`. 93
occurrences of `agent-specific/claude` now exist in repo source (0 at baseline); 50 of
them across 18 files are already synced live into `~/.claude/`.

Crucially, **the executable core survived** — `sync-install.sh`'s real code, `resolve-config.sh`'s
real chain, and `agent-specific/claude/settings.json`'s hook commands all still correctly
say `$HOME/.claude`. That is why the install is byte-identical and `--check` is clean.
The damage is concentrated in (a) a handful of hook scripts' path constants, and (b) the
instruction layer that agents read as truth.

### Class 2 — missed rename (C3)

The `generic/` pattern carries a **trailing slash**, so it matched prose and path literals
but *not* bare shell word lists. `agent-agnostic/hooks/claude-install-drift.sh:81` still reads:

```bash
for top in generic orchestrators; do          # 'generic' — no slash, so rename.py skipped it
  cand="$AGENTIC_REPO/$top/$kind/$rest"
```

Verified byte-identical to baseline (`git show fc097d1:generic/hooks/claude-install-drift.sh`),
while the human-readable message eight lines below *was* rewritten to `agent-agnostic/` —
the two halves of the same function now disagree. This is a distinct defect from Class 1 and
survives a Class-1-only fix.

## Ranked candidates

Ranked on **likelihood × ease** (likelihood = strength of evidence that this is an actual
Claude regression; ease = implement *and* verify). Each entry's file list is that fix
lane's file scope. Test oracle for every candidate: **the reproduction** — the repro no
longer triggers and the existing suites (`tests/verify-scope-parsing.test.sh`,
`tests/plan-lifecycle.test.sh`) stay green.

- [x] **[APPROVED · step 3] C1: `dae` skill's `Stop` hook points at a nonexistent script.** *Likelihood: High
  (observed on disk, live in the install). Ease: High (one-line).*
  `orchestrators/skills/dae/SKILL.md:14` frontmatter declares
  `command: "~/.agent-specific/claude/hooks/workflow-diff-check.sh"`. The real script is
  `~/.claude/hooks/workflow-diff-check.sh` (present, executable); the declared path does
  not exist. Already synced to `~/.claude/skills/dae/SKILL.md:14`, so **every `/dae` run's
  Stop hook currently fires against a dead path** — the end-of-run diff check silently
  does not run. This is the flagship orchestrator skill and the single highest-impact find.
  *Fix:* `~/.agent-specific/claude/hooks/` → `~/.claude/hooks/`, then re-sync.
  *Files:* `orchestrators/skills/dae/SKILL.md`.

- [x] **[APPROVED · step 2] C2: `claude-install-drift.sh` resolves `CLAUDE_HOME` to a nonexistent directory.**
  *Likelihood: High (reproduced, both failure directions). Ease: High (one-line).*
  `agent-agnostic/hooks/claude-install-drift.sh:40` —
  `CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.agent-specific/claude}"`, contradicting its own
  header comment five lines above which still documents the default as `$HOME/.claude`.
  No `CLAUDE_HOME` is exported anywhere (checked `printenv`, `.bashrc`, `.zshrc`,
  `.profile`), so the broken default always applies. Wired `PostToolUse` on
  `Write|Edit|MultiEdit` (`agent-specific/claude/settings.json`), so it runs on every edit.
  Both directions are broken: editing `~/.claude/hooks/*.sh` produces **no advisory at all**
  (the "you edited the install, it will be overwritten" safety net is dead), and editing
  repo source produces a **permanent false "install is stale"** warning, even right after a
  verified-clean sync. Advisory-only (never blocks), but it is now pure noise plus a lost
  guardrail. *Fix:* restore `$HOME/.claude`. *Files:* `agent-agnostic/hooks/claude-install-drift.sh`.

- [x] **[APPROVED · step 1] C3: `claude-install-drift.sh` still searches the deleted `generic/` directory.**
  *Likelihood: High (reproduced on the real machine). Ease: High (one word).*
  `agent-agnostic/hooks/claude-install-drift.sh:81` — `for top in generic orchestrators`, byte-identical
  to baseline, was never updated when `generic/` became `agent-agnostic/`. The install→source
  lookup can therefore only ever resolve files that live under `orchestrators/`; **everything
  that moved to `agent-agnostic/`** — `smart-lint.sh`, `smart-test.sh`, every rule, most skills —
  is now unfindable. Reproduced with `CLAUDE_HOME` explicitly set to the real `$HOME/.claude`
  and the real `$HOME/repos/agentic`: editing an installed hook that *does* have a source
  counterpart emits the false advisory "edited the INSTALL; no source counterpart found".
  **This is independent of C2 and survives fixing it** — correcting `CLAUDE_HOME` alone just
  moves the hook from silently dead to loudly wrong. The same function's message string eight
  lines below already says `agent-agnostic/`, so the file contradicts itself.
  *Fix:* `for top in agent-agnostic orchestrators`. *Files:* `agent-agnostic/hooks/claude-install-drift.sh`.

- [x] **[APPROVED · step 2] C4: `worktree-reminder.sh` instructs every session to run a nonexistent script.**
  *Likelihood: High (observed; fires on every non-worktree session). Ease: High.*
  `agent-agnostic/hooks/worktree-reminder.sh:46` — the `SessionStart` message tells the
  agent to set up a worktree "via `~/.agent-specific/claude/hooks/workflow-setup.sh`".
  That path does not exist; the real one is `~/.claude/hooks/workflow-setup.sh`. Wired as
  a `SessionStart` hook, so it reaches Claude at the start of every session begun outside
  a worktree — the exact moment the agent is most likely to act on it.
  *Fix:* correct the path in the message string. *Files:* `agent-agnostic/hooks/worktree-reminder.sh`.

- [x] **[APPROVED · step 4] C5: The always-on instruction layer asserts a false install path.** *Likelihood:
  High (self-demonstrated this session). Ease: Medium (wide but mechanical; must not
  clobber legitimate repo-source paths).*
  ~25 source files, and **18 already-installed files / 50 occurrences** under `~/.claude/`,
  tell agents the global install is `~/.agent-specific/claude/` and the project config is
  `.agent-specific/claude/`. Both are false. The highest-impact members are the always-on
  rules and agent definitions injected into every session:
  `agent-agnostic/rules/artifact-locations.md` (5), `run-artifacts.md` (1), `plan-format.md` (1),
  `orchestrators/agents/builder.md` (2), `planner.md` (1),
  `agent-agnostic/skills/{review-plan,review-code,review-pr,comment-pr}/SKILL.md`,
  `orchestrators/skills/dae/SKILL.md` (4), `dae/worktree-modes.md` (1),
  plus this repo's own `.claude/rules/source-push-sync.md` and `.claude/skills/push-main/SKILL.md`,
  and docs/README/AGENTS files. `source-push-sync.md:9` additionally names a source path
  that has never existed, `agent-agnostic/settings/settings.json` (verified absent); the real
  one is `agent-specific/claude/settings.json`.
  Evidence it is live and load-bearing: the planner repro above, and the fact that this
  conversation's own injected system context contains the corrupted text verbatim.
  *Fix:* corrected substitution reverting install/project-config mentions only, leaving
  `agent-agnostic/` and `agent-specific/…` **repo** paths and all `~/.gemini/config/…`
  mentions untouched. *Files:* the ~25 listed above, then re-sync.

- [x] **[APPROVED · step 2] C6: `smart-test.sh`'s "skip tests for hook files" exclusion is dead for Claude.**
  *Likelihood: High (reproduced A/B). Ease: High.*
  `agent-agnostic/hooks/smart-test.sh:170` matches
  `/.agent-specific/claude/hooks/.*\.sh$`, which can never match a real edit at
  `/home/icarus64/.claude/hooks/*.sh`; the original `/.claude/hooks/` arm was dropped
  outright. The sibling alternatives `/claude-code/hooks/` and `/.gemini/config/hooks/` are
  intact, so **Antigravity keeps the exclusion and Claude loses it.** Reproduced with a real
  PostToolUse Edit payload on `$HOME/.claude/hooks/smart-lint.sh`: baseline short-circuits
  with `[INFO] Skipping tests for hook file: …`; current falls through into full test
  discovery. Exit code happens to match in a bare context, but in a project with a real test
  runner this attempts to discover and run tests against a hook script it is supposed to
  ignore — and `smart-test.sh` blocks on exit 2.
  *Fix:* restore a `\.claude/hooks/` alternative alongside the new arms.
  *Files:* `agent-agnostic/hooks/smart-test.sh`.

- [x] **[APPROVED · step 2] C7: `record-changed.sh` / `test-changed.sh` state dir and self-exclusion moved to a
  nonexistent tree.** *Likelihood: Low (code-confirmed but dormant — the pair is wired
  nowhere, and `workflow-diff-check.sh` documents itself as their replacement). Ease: High.*
  `record-changed.sh:30` and `test-changed.sh:35` both changed
  `dir="$HOME/.claude/state/test-changed"` → `"$HOME/.agent-specific/claude/state/test-changed"`.
  Writer and reader moved together, so the pair is self-consistent — but it would create
  state outside the install root and orphans the existing real state dir
  (`/home/icarus64/.claude/state/test-changed`, present since Jul 2). Separately,
  `record-changed.sh:27`'s self-exclusion arm `*/.agent-specific/claude/hooks/*) exit 0` no
  longer matches the real install path, so edits to installed hooks would now be recorded
  as changed files — the exact case the guard exists to suppress. Neither script appears in
  `agent-specific/claude/settings.json`'s wiring today, which is why this is dormant rather
  than live. Note `agent-agnostic/AGENTS.md:68` still claims the pair is "wired via
  settings.json" — stale independently of this port.
  *Files:* `agent-agnostic/hooks/record-changed.sh`, `agent-agnostic/hooks/test-changed.sh`.

- [x] **[APPROVED · step 2] C8: `claude-install-drift.sh`'s "never synced" arm no longer matches the repo's own
  project dir.** *Likelihood: Medium (code-confirmed). Ease: High.*
  `agent-agnostic/hooks/claude-install-drift.sh:107` excludes
  `"$AGENTIC_REPO"/.agent-specific/claude/*` from sync consideration, but this repo's
  project-scoped dir is literally `.claude/` (it is where `source-push-sync.md` and the
  `push-main` skill live). Editing those files therefore no longer takes the "never synced"
  branch. Bundle with C2 and C3 — same file.
  *Files:* `agent-agnostic/hooks/claude-install-drift.sh`.

- [x] **[APPROVED · step 5] C9: `resolve-config.sh` consults Gemini's settings ahead of Claude's.**
  *Likelihood: Low (dormant — reproduced as having zero effect today). Ease: High.*
  `orchestrators/hooks/resolve-config.sh:59-61` inserted
  `$HOME/.gemini/config/settings.json` **before** `$HOME/.claude/settings.json` in the
  resolution chain. A/B execution of the baseline and current scripts for all four vars
  (`CLAUDE_DOCS_DIR`, `CLAUDE_PROJECT_PLANS_DIR`, `CLAUDE_WORKFLOWS_DIR`,
  `CLAUDE_BASE_BRANCH`) from two roots produced **identical values in every case**, because
  `$HOME/.gemini/config/settings.json` does not currently exist. The latent risk is real: if
  Antigravity ever writes an `env.CLAUDE_*` key there, Claude Code sessions would silently
  prefer Gemini's value with no error.

  **Gate decision (DP2, option b): this is an approved FIX, not leave-as-is.** Reorder the
  global tier of the chain so **each tool prefers its own config** — both `~/.claude` entries
  rank AHEAD of `~/.gemini/config/settings.json`. The project-scoped tiers
  (`<root>/.agents/…`, `<root>/.claude/…`) keep their current relative order; only the
  `$HOME` tier is reordered, to:

  ```
  $HOME/.claude/settings.local.json   (if the script carries one at this tier)
  $HOME/.claude/settings.json
  $HOME/.gemini/config/settings.json
  ```

  Acceptance: the four-var × two-root A/B still resolves identically to baseline, and a
  temporary `$HOME/.gemini/config/settings.json` defining `env.CLAUDE_DOCS_DIR` is
  demonstrably **not** preferred over a `~/.claude/settings.json` value (revert the probe
  afterwards — it must not be left on disk). *Files:* `orchestrators/hooks/resolve-config.sh`.

- [x] **[APPROVED · step 5] C10: `smart-lint.sh` / `smart-test.sh` dropped their malformed-stdin CLI fallback.**
  *Likelihood: Low (reproduced, but unreachable from real Claude payloads). Ease: Low-Medium.*
  Baseline let unparsable stdin fall through to a repo-wide check (the documented ad-hoc /
  manual-pipe path); both now `exit 0` immediately with a fail-open log line. Reproduced with
  `echo 'not json at all' | <script>`: baseline runs the project-type detection and style
  check, current exits at once. Claude Code always sends valid JSON, so no hook-path impact —
  recorded for completeness, and only relevant if anyone invokes these scripts by hand.
  *Files:* `agent-agnostic/hooks/smart-lint.sh`, `agent-agnostic/hooks/smart-test.sh`.

- [x] **[APPROVED · step 5] C11: One-shot migration scripts left committed at the repo root.** *Likelihood: Low
  (hygiene, not a behavior regression). Ease: High.*
  `rename.py` and `rename_tools.py` have no ongoing purpose now that the migration has
  landed, and `rename.py` is precisely the blunt instrument that caused C1–C8. Leaving it
  in a repo whose product is precise agent instructions invites a repeat.
  *Files:* `rename.py`, `rename_tools.py`.

- [x] **[APPROVED · step 4] C12: Stale header comments in two scripts.** *Likelihood: Low (comment-only, zero
  execution impact). Ease: High.*
  `orchestrators/hooks/sync-install.sh:9-24` and
  `agent-agnostic/hooks/claude-install-drift.sh:24-26` still describe sources as
  `{generic,orchestrators}/…` (a dir that no longer exists) and destinations as
  `~/.agent-specific/claude/…`. The code beneath `sync-install.sh`'s comment is correct;
  the code beneath `claude-install-drift.sh`'s is **not** (that is C3). Bundle with C2/C5.

## Verified clean — positive assurance

The user asked explicitly for confirmation of what did **not** regress. Each item below
was verified by execution or byte-comparison, not by reading alone.

**Hook wiring — clean.**
`git show fc097d1:claude/settings.json`, HEAD's `agent-specific/claude/settings.json`, and
the live `$HOME/.claude/settings.json` are **byte-identical to one another** (the file moved
in a 100%-similarity rename and its content never changed). All 9 wired hook commands
resolve to existing, executable files under `~/.claude/hooks/`. No `env` block exists in any
of the three — and none existed at baseline either, so nothing was lost.

**The install itself — clean.**
Independently of the Antigravity agent's claim, `agent-agnostic/{hooks,rules,skills}` +
`orchestrators/{hooks,agents,skills}` were merged into a scratch tree and compared with
`diff -rq` against `~/.claude/{hooks,rules,agents,skills}`: **zero differences, zero orphans
in either direction.** `sync-install.sh --check` (confirmed read-only from its code, then run)
reports `CHECK (claude): clean` and `CHECK (agy): clean`, the only drift being the documented,
expected `STALE: settings.json` from Claude Code's live permission-grant appending. The sync
the writeup claimed did in fact run.

**Unit mapping completeness — clean.**
Normalized tracked-file lists for baseline (`generic`+`orchestrators`+`antigravity`+`claude`
at `fc097d1`) vs HEAD (`agent-agnostic`+`orchestrators`+`agent-specific`): **74 files each
side, byte-identical sets, zero diff.** Nothing baseline synced is missing at HEAD, and no
destination changed beyond the intended source-dir rename. HEAD in fact *fixes* a baseline
bug: baseline's ranged sync filtered only `-- generic orchestrators`, so `settings.json`
changes could never be picked up by a non-`--full` sync.

**`scope-writes.sh` (the anti-cheating gate) — clean, 17/18 cases byte-identical.**
Baseline and current were executed against 18 synthetic Claude payloads, diffing stdout,
stderr and exit code: in-scope allow, out-of-scope deny (identical denial text), Edit,
NotebookEdit, Bash pass-through, Read, empty stdin, garbage stdin, missing `tool_name`, and
`CLAUDE_SCOPE_ALLOW` unset/empty. Critically, **four adversarial payloads** embedding literal
`"file_path"` / `"TargetFile"` / `"notebook_path"` strings inside the `content` field, in both
orderings (fake key before and after the real one), could not hijack the naive regex — JSON's
mandatory `\"` escaping inside string values means an embedded fake key never presents a bare
`"key"` substring. The feared misfire is not reachable. The single differing case is C-DP1 below.

**`branch-squash-guard.sh` — clean, 32/32 cases byte-identical.**
Covering genuine Mode A (real `dev`+`main`) and Mode B (`main`-only) repos: commit/write
denials on the integration branch, `git merge`/`gh pr merge` without `--squash` denied and
with `--squash` allowed, `git push --force` denied, feature-branch operations allowed, and
the `CLAUDE_HOTFIX_MAIN_AUTHORIZED=1` bypass lifting only the commit-on-main denial while
squash-always still holds.

**`allow-workflow-cleanup.sh` — clean, ~10/10 cases byte-identical.**
Despite being touched by two of the five commits (`5f4ecc2` and `548fa04`), it is fully
behaviourally equivalent to baseline for Claude payloads. A/B covered: safe `git branch -d`
approval, safe lane-child `git worktree remove` approval, refusal to approve `-D` force
delete, `&&`-chained command rejection, `cwd` present vs absent (identical `pwd` fallback),
non-Bash tool names, and — importantly — `mcp__server__run_command` correctly **not** matched
by the new `*:run_command` arm. Exercised against a synthetic git-worktree fixture so the real
branch/worktree resolution logic ran, not just the early exits.

**`smart-lint.sh` — clean** for genuine Claude `Write|Edit|MultiEdit` payloads (verified with
in-repo and outside-repo targets and empty stdin); its new `notebook_path`/`TargetFile`/
`target_file`/`path` fallbacks are Antigravity-only or never sent by the tools that trigger
its matcher. **`agy-hook-adapter.sh` — clean**, its diff is comment-only.

**The Antigravity fallbacks are unreachable for Claude — proven, not assumed.**
The shared `field()` extractor uses plain `grep -oE` with the key interpolated literally and
**no `-i` flag**: `field cwd` does not match `"Cwd"` and `field Cwd` does not match `"cwd"`.
Its function body is byte-for-byte unchanged from baseline; only three fallback *call sites*
were added, each guarded by `[ -n "$x" ] ||`. Since Claude always emits `file_path`, `cwd` and
`command`, the new `TargetFile`/`Cwd`/`CommandLine` lines never execute on genuine Claude
traffic. Confirmed with adversarial payloads embedding fake `"CommandLine"`/`"Cwd"` substrings
in `description`, and with an empty-string `"cwd":""` payload (falls through to `pwd` identically
in both versions).

**`resolve-config.sh` — clean in practice.**
A/B of baseline vs current for all four config vars from two roots: identical resolved values
every time. The only difference is a cosmetic stderr `source:` label naming `.agents/settings.json`
instead of `.claude/settings.json` — the same file via the `.agents → .claude` symlink. Every
caller in the repo (`workflow-setup.sh`, `plan-lifecycle.sh`, `branch-squash-guard.sh`,
`verify-run-scope.sh`, `allow-workflow-cleanup.sh`) reads only stdout, never that label.
All three `.agents` entries found on this machine are symlinks to `.claude`; none is a real
directory.

**Existing test suites — green.** `tests/verify-scope-parsing.test.sh` 20/20 PASS and
`tests/plan-lifecycle.test.sh` 20/20 PASS against the current tree. Neither suite was touched
in the suspect range. Note the coverage gap recorded under open questions.

**No stale `generic/` references** survive anywhere in the worktree except inside `rename.py`'s
own replacement table. **All ~28 script paths** referenced from skills, agents, rules and hooks
resolve to real files at HEAD (one pre-existing, unrelated exception:
`agent-agnostic/hooks/README.md:120` cites `example-claude-hooks-config.sh`, which has never
existed in this repo's history).

**Antigravity's side cannot reach Claude.** Every `command:` in
`agent-specific/antigravity/hooks.json` points at `~/.gemini/config/hooks/*`; it is referenced
only from `--agy`-gated logic in `sync-install.sh`. Commit `276d92c` touched that file alone,
so it has **zero** Claude impact. `tool-based/` is untouched apart from a one-line `AGENTS.md`
edit, and the four `agent-specific/antigravity/skills/*` are **newly created files**, not
relocations of existing tech-domain skills — no skill was taken away from Claude.

**`.gitignore` is unchanged** across the range, so `.workflows/` and `.artifacts/` isolation
still holds. **`rename_tools.py`'s** edits are correctly scoped — the only content change it
made is `"Bash tool"` → `"Bash/run_command tool"` in `agent-agnostic/rules/shell-discipline.md`,
a compatible broadening, not a regression.

## Diff summary

| Commit | Claude impact |
|---|---|
| `711f1c8` agy framework rework | **The sole source of every High candidate.** Renamed the source dirs correctly, but `rename.py`'s unanchored `'claude/'` rule corrupted ~93 install-path references across hooks, rules, skills, agents and docs (Class 1), while its slash-terminated `'generic/'` rule missed the bare word list in `claude-install-drift.sh:81` (Class 2). |
| `acad713` correct claude_home and path resolutions | Touched `agent-specific/claude/settings.json` + `sync-install.sh`. Net effect verified benign: settings content is byte-identical to baseline, and `sync-install.sh`'s code correctly targets `$HOME/.claude`. Did not repair the `711f1c8` prose damage. |
| `276d92c` port scope-writes + workflow-diff-check to agy | `agent-specific/antigravity/hooks.json` only. **Zero Claude impact** (verified). |
| `5f4ecc2` add Antigravity tool/param shapes | The four script rewrites — **the part Antigravity's writeup is about, and the part that is fine.** Verified behaviour-preserving for Claude across ~60 A/B cases; the only difference is the deliberate `MultiEdit` widening (DP1). |
| `548fa04` add missing `Cwd` fallback | One guarded fallback line in `allow-workflow-cleanup.sh`. Unreachable for Claude payloads (`field()` is case-sensitive; Claude always supplies `cwd`). Verified clean. |

**The headline:** the writeup's four "critical guardrail" rewrites did **not** regress Claude.
Every real regression comes from `711f1c8`, the commit the writeup does not mention.

## Risks, open questions, decision points

> **All four items below were settled at the Round 1 gate on 08-15-26.** Each carries its
> resolution inline; the reasoning is preserved as the justification for the decision.
> See "Gate decisions — Round 1" at the top of this file for the consolidated list.

**DP1 — RESOLVED: keep the widening. `scope-writes.sh` enforcing `MultiEdit` is ratified as
a deliberate tightening; no code change required.**
This is the one genuine Claude behaviour change in the four rewritten scripts, and it is
almost certainly a **fix, not a regression**. At baseline `scope-writes.sh` matched only
`Write|Edit|NotebookEdit`, so with `CLAUDE_SCOPE_ALLOW` set, a `MultiEdit` to *any* path —
including outside the allowed scope — bypassed the anti-cheating gate entirely. Reproduced:
baseline exits 0 silently, current exits 2 with the denial. `MultiEdit` is a live Claude tool
already present in this repo's own matchers, and the gap is named in
`project-plans/agy-framework-rework-08-14-26/plan.md:24,74`. Given the structural
anti-cheating principle, closing it is the right call — but it is a behaviour change and the
user should ratify it rather than have it slipped in.
*Options were:* (a) keep the widening (recommended); (b) revert to baseline matching.
**Decision: (a).** The fix lane must NOT revert it, and the C5 prose sweep must not describe
the gate as covering only `Write|Edit|NotebookEdit`.

**DP2 — RESOLVED: option (b). Each tool prefers its own config; C9 becomes an approved fix.**
The question was whether `~/.gemini/config/settings.json` should outrank
`~/.claude/settings.json` for a Claude session (C9). Dormant today.
*Options were:* (a) leave as-is; (b) move both `~/.claude` entries ahead of the Gemini one;
(c) make the Gemini candidate conditional on detecting a Gemini/Antigravity runtime.
**Decision: (b)** — see C9 for the concrete reordering and its acceptance check.

**DP3 — RESOLVED: option (b). One full ~25-file prose sweep.**
*Options were:* (a) fix only the executable and always-on-rule occurrences (C1–C4 plus
`artifact-locations.md`/`run-artifacts.md`/`plan-format.md`/`builder.md`/`planner.md`),
leaving docs/README for later; (b) fix all ~25 files in one pass.
**Decision: (b)** — mechanical, and avoids a second corrupted-prose round.

**Open question — RESOLVED: `~/.agent-specific/claude/` was an ACCIDENT.** Every piece of
evidence said accident: the executable code never adopted it, the directory was never
created, and `claude-install-drift.sh`'s own comment still documents `$HOME/.claude`.
**The gate confirmed this.** The install root **is and stays `~/.claude/`**, project config
stays `.claude/`, `~/.agent-specific/` must not be created, and **C1–C8 stand as written
rather than inverting**. No migration of the live install is in scope.

**Unverified / could not verify.**
- `workflow-diff-check.sh`'s and `claude-install-drift.sh`'s *functional* behaviour beyond
  path resolution was not exercised end-to-end.
- Projects outside `/home/icarus64` were not checked for a real (non-symlink) `.agents/` dir,
  which is the only condition under which C9's precedence entries could bite today.
- **Coverage gap:** `tests/` covers only `verify-scope.sh`/`verify-run-scope.sh` and
  `plan-lifecycle.sh`. There is **no test coverage at all** for `scope-writes.sh`,
  `branch-squash-guard.sh`, `allow-workflow-cleanup.sh`, or `claude-install-drift.sh` — which
  is why this regression went unnoticed. Worth a follow-up plan; the A/B harnesses built during
  this investigation are a natural seed for it.

## Skill mapping

| Work | Skill / agent |
|---|---|
| Gate on this report, settle DP1–DP3 and the open question | `review-plan` + the human gate — **DONE, Round 1, 08-15-26** |
| Implement all twelve approved candidates | `dae` build stage, `builder` (single lane — see below) |
| Re-sync the install after the fix lands | `push-main` step 6 (`sync-install.sh`), per `source-push-sync` |
| Verify the fix | the repros above, plus `tests/*.test.sh` and `sync-install.sh --check` |

**Test oracle for the fix lane:** the reproduction — every repro in this file must stop
triggering, and `tests/verify-scope-parsing.test.sh` + `tests/plan-lifecycle.test.sh` must
stay 20/20 green. C9 additionally declares **new contract tests** for its reordering (the
Gemini-vs-Claude precedence probe in its acceptance criteria), since it changes behaviour
rather than restoring baseline.

**Definition of done for the lane:** zero occurrences of `agent-specific/claude` remain as an
*install or project-config* path anywhere in repo source (repo-source paths
`agent-agnostic/`, `agent-specific/claude/settings.json`, `agent-specific/antigravity/` are
correct and must survive), `grep -rl '\.agent-specific' ~/.claude` returns nothing after the
re-sync, and `sync-install.sh --check` is clean apart from the documented `settings.json`
STALE line.

**Lane shape: serial, one lane.** C1–C8 and C12 share one root cause and overlap heavily on the
same files (`claude-install-drift.sh` alone appears in C2, C3, C8 and C12; the corrected
substitution in C5 touches files that C1, C4 and C6 also touch). Splitting them would put two
lanes in the same files, which `plan-format` forbids. C9–C11 are independent but trivial and
not worth a lane of their own. **Confirmed at the gate: single serial lane for all twelve.**

**Fix order within the lane** (approved at the gate; the `step N` tags on each candidate map
to these), so each step is verifiable before the next:

1. **Step 1 — Class-2 code fix:** C3.
2. **Step 2 — Class-1 path constants:** C2, C4, C6, C7, C8.
3. **Step 3 — skill frontmatter:** C1.
4. **Step 4 — the full prose sweep (DP3 option b, all ~25 files in one pass):** C5, C12.
5. **Step 5 — hygiene and the DP2 fix:** C9, C10, C11.

Then run `sync-install.sh` and re-run every repro in this file plus both test suites.
