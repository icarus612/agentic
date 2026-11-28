# Optional inputs are not dead code

A prop, argument, parameter, or option that no current caller passes is **not** unused code. Optional inputs exist for flexibility: a component or function does not have to be exercised in every way by every page or caller that uses it today.

**Why:** a run once labelled a hero's `compactOnMobile`/`slowStream` props "dead code" because the one page that passed them switched heroes. A plan offered to delete them, and the PR gate listed them as a follow-up cleanup. The owner's correction: "Props dont have to be used every page the whole point is flexibility... an arg/prop not being used current is not unused code."

## What this means

- Never flag an optional input as dead, unused, or stale just because no current caller sets it.
- Never raise a decision point, finding, or follow-up proposing to remove it on that basis.
- Never describe it in docs or changelogs as "unused". Describe it as an optional input with its default.
- "Delete old code" means replaced implementations, compatibility shims, and superseded paths. It never means optional parameters of a live component or function.

## What still counts as dead code

Code that cannot execute or that was replaced: an unreachable branch, a function or component nothing imports, an implementation superseded by its replacement. Removing the input's *behaviour* while keeping the input is a different bug: an input that is accepted but ignored is a defect, not flexibility.

This holds for every agent, including planners, builders, review gates, and documenters, whether or not a dispatch repeats it.
