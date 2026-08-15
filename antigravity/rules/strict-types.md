---
trigger: file_extension matches [.ts, .py, .gd]
---
# Typing Rules
1. **TypeScript:** Do not use `any`. Use `unknown` or define a specific Interface/Type.
2. **Python:** All function signatures must have Type Hints (PEP 484). Return types are mandatory.
3. **GDScript:** Use static typing syntax (e.g., `var health: int = 100` instead of `var health = 100`).