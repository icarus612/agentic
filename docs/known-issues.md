# Known issues

This page is the docs root's home for known gaps in current behavior and for work that is parked
on purpose. An entry here is **not** a bug report and **not** a backlog: it records a limitation
someone will actually hit, states whether anything is planned about it, and points at where that
plan lives. A parked proposal listed here is deliberately parked, not stale — it is not to be
deleted as cleanup.

Each entry follows the same shape: the limitation, where it's visible in the source, and its
status (parked with a pointer / no plan / fixed and awaiting removal).

## `-w none`: single-lane, no run dir

**Limitation.** `--worktree none` runs every stage in the current checkout with no worktree at
all, and restricts builder dispatch to ONE lane at a time — there are no child worktrees, so
there is no physical isolation for parallel builders (`agent-agnostic/skills/dae/worktree-modes.md:13-15`
for the mode's definition; `agent-agnostic/skills/dae/build.md:27` for the single-lane
consequence). Because there is no parent worktree, this mode also creates no run dir (no
`.artifacts/`) — which is why it has no progress log either.

**Source.** `agent-agnostic/skills/dae/worktree-modes.md:13-15`, `agent-agnostic/skills/dae/build.md:27`.

**Status.** Parked with a pointer. The redesign under discussion has the current checkout become
the run's PARENT while builder lanes still get isolated child worktrees, plus a new
`workflow-setup.sh` mode that creates only the run dir (no full parent worktree). See
`project-plans/proposals/none-mode-parent-08-28-26.md` — that proposal is **intentionally parked,
not stale**: it was split out of an unrelated plan on purpose, and stays here until someone picks
it up deliberately.
