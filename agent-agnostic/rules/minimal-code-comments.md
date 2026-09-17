# Minimal code comments

Write as few code comments as possible. Explanatory prose, rationale, and "why we did it this way" belong in the docs root (see `doc-format`) and the changelog — never inline.

**Why:** long inline comment blocks are noise that duplicates documentation and rots independently of it. A project with a docs root as its single source of truth makes inline rationale redundant by construction.

## The bar

Comment only what the code genuinely cannot say — a non-obvious constraint, or a real gotcha that would bite the next reader. One or two lines.

**Forbidden:**
- multi-line banner comments at the top of a file or block
- comments restating what the next line does
- essays in prop docblocks
- narrating *why this test exists* above each test — the test name carries that
- explaining a convention that is already written down in the project's own instruction file or docs

**Tests are not exempt.** They are the most common offender: a test file that is one-quarter to one-third comment lines is a violation, not thoroughness. If a test needs a paragraph to justify it, the paragraph belongs in the changelog entry or the docs page for that change.

When there is a real explanation worth keeping, write it in the relevant page under the docs root and let the code stay bare.

## This is universal — it is never conditional on being mentioned

This rule is always-on context for every agent: orchestrators, builders, `coder`, `contract-tester`, and every review-gate and committee member. It holds whether or not a dispatch repeats it, whether or not a plan's "Conventions to enforce" lists it, and whether or not a reviewer was told to look for it.

**It is not something to remember to pass down.** A standard that holds only when someone restates it is not a standard. If an agent produced heavily-commented code, the defect is the code — "nobody told me" is not a defence, and neither is "the gate passed it".

Enforcement is mechanical, at the two points where the lifecycle ends:

- **builder teardown** — `check-diff-hygiene.sh` runs over the lane diff before the exit report is written; a violation is the builder's own defect to fix, not a note to carry forward.
- **the draft → ready flip** — `pr-ready-hygiene-guard.sh` blocks `gh pr ready` at the harness level, so no agent can route around it by calling `gh` directly.

Those hooks are the enforcement. This prose only explains what they check and why.
