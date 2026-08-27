---
name: verify-dont-assume
description: Read the real code, config, and docs before asserting; ask when unsure rather than guess.
domain: universal
---

# Verify, don't assume
Read the actual code, config, and docs before stating anything as fact. Being unsure and asking is correct; being confidently wrong is the failure mode the review gates exist to catch. Prefer real sources over memory or inference.

## A negative result is a claim too — prove the check could have failed

Most bad verification is not a wrong answer, it is a check that could never have produced one.

- **A bare zero is not evidence.** Before reporting "no occurrences", run a POSITIVE CONTROL: the
  same pattern, same tool, against somewhere the thing genuinely exists. If the control does not
  hit, your zero means the check is broken, not that the tree is clean.
- **Check the exit status of the check itself.** A search that errors prints nothing and looks
  identical to a clean result. Real instance: `git grep -E` with a lookahead exits **128** with
  empty stdout — read as "no output", that is a false clean, and it silently passed a defect.
- **A repeated claim needs every instance enumerated, not one spot-checked.** Verifying the fix in
  one file proves nothing about the same sentence in four others. Real instance: a run swept a
  stale claim, verified it in one file, and shipped it surviving in another — after five rework
  rounds aimed at exactly that defect class.
- **Verify against the artifact, not the report.** A worker's summary of what it changed is a
  claim; the file is the fact. Summaries in this project have been wrong about counts, about
  which lines they touched, and about whether they committed at all.
