---
trigger: always
---
# Universal Constraints
1. **No Magic Numbers:** Define constants for all numeric values, especially in Godot/game logic (e.g., movement speed, timeout durations).
2. **No 'TODO' Comments without Owners:** If you generate a TODO, you must append `(User)` or a specific issue ticket format.
3. **Secrets:** NEVER output hardcoded API keys or passwords. Suggest environment variables (`.env`) instead.