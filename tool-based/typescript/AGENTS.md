# JavaScript · Node — stack instructions

Conventions and defaults for Node.js / TypeScript projects (pnpm, module layout,
strict typing). Framework-agnostic — framework-specific typing (Svelte, React)
lives in those stacks. TypeScript runs in strict mode; external data is `unknown`
until narrowed with a type guard; variant state is modelled as discriminated
unions; magic numbers become named constants.

## Rules
- **typescript-strict** — `strict` on always; never `any` (use `unknown` +
  narrow); type every signature; type at boundaries; discriminated unions for
  variants; avoid `as`.
- **code-quality** — naming conventions (camelCase / PascalCase /
  UPPER_SNAKE_CASE / kebab-case files); constants over magic numbers; handle
  errors at boundaries; no commented-out code or stray `console.log`; import
  ordering.
- **package-manager** — pnpm only, always; never npm or yarn, even when an
  existing lockfile says otherwise (flag and convert, don't defer — confirm
  first on an established project).

## Skills
- **type-safely** — procedures and examples for type guards, discriminated
  unions, generic utility types, and typing external/API responses without
  `any` or `as`.
