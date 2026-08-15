---
name: tech-agnostic
description: Never assume or hard-code a stack; technologies named in a universal skill are examples only — discover the real stack from the project.
domain: universal
---

# Tech-stack agnostic
Never assume or hard-code a stack. Any technology named in a `domain: universal` skill is an example only — discover the real stack from the project (manifests and lockfiles, never memory), then load the skills and rules whose `domain:` names that technology. This is `verify-dont-assume` aimed at the stack: an example in a skill body (e.g. a Svelte or Python idiom) is never evidence the project uses it.

Authoring corollary: a skill is bound to nothing (`domain: universal`) or to exactly one technology (`domain: <tech>`). Never bake a stack into a universal skill; tech-specific guidance belongs in a skill whose `domain:` names that tech, installed alongside the project that uses it.
