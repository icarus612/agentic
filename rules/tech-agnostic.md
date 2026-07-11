---
name: tech-agnostic
description: Never assume or hard-code a stack; technologies named in a skill are examples only — discover the real stack from the project.
type: rule
domain: universal
---

# Tech-stack agnostic
Never assume or hard-code a stack. Any technology named *in a skill* is an example only — discover the real stack from the project and load the matching `stacks/<tech>/` layer. This is `verify-dont-assume` aimed at the stack: an example in a skill body (e.g. a Svelte or Python idiom) is never evidence the project uses it.

Authoring corollary: don't bake a stack into skill bodies; keep stack-specific guidance in `stacks/<tech>/`.
