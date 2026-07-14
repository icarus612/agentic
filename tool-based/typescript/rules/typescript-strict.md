---
name: typescript-strict
description: TypeScript strict-mode laws — strict on, never `any`, type at boundaries, discriminated unions for variants.
domain: typescript
---

# TypeScript strict mode

- **`strict` is on, always.** `compilerOptions.strict` must be `true` in
  `tsconfig.json` — never disable it or its member flags (`noImplicitAny`,
  `strictNullChecks`, etc.) to silence an error.
- **Never `any`.** When a type is genuinely unknown, use `unknown` and narrow it
  with a type guard before use. Reach for a specific `interface`/`type` or a
  generic before you reach for `unknown`. `any` (explicit or implicit) is
  forbidden.
- **Type every signature.** All function parameters and return types are
  explicit — no implicit `any` parameters, no inferred public return types.
- **`interface` for object shapes, `type` for unions and mapped types.**
- **Type at the boundary.** Data entering the program from outside (network
  responses, JSON, env, user input) is `unknown` until validated. Define an
  `interface` for its shape and narrow with a type guard at the edge — never
  cast raw external data straight into a trusted type.
- **Discriminated unions for variants.** Model state machines and multi-shape
  values as a union with a shared literal tag (`status`, `kind`, `type`) so the
  compiler enforces exhaustive handling — never a bag of optional fields.
- **Avoid type assertions (`as`).** Prefer type guards and `instanceof` narrowing.
  Use `satisfies` to check a value against a type without widening it.
