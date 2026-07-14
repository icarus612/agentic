---
name: run-godot-test
description: Run a Godot scene or script headlessly to sanity-check logic without opening the editor — use to verify scripts with testable output (prints, assertions).
domain: godot
rules: [gdscript-standards]
model: sonnet
model-fallback: [gemini-pro]
---

# run-godot-test

Execute a Godot scene or script in headless mode to verify logic without
launching the full editor.

## Command

```bash
godot --headless --path . -s <path_to_scene_or_script>
```

- `--headless` runs with no window or rendering.
- `--path .` sets the project directory to the current directory.
- `-s <path>` runs the given `.tscn` or `.gd` as a script.

## Usage

Use this to sanity-check scripts that produce testable output — `print()`
statements or `assert()` calls. Replace `<path_to_scene_or_script>` with the
`res://`-relative path to run.

```bash
godot --headless --path . -s res://tests/test_hex_neighbors.gd
```

Read the printed output (and non-zero exit on a failed `assert`) to confirm the
logic behaves as expected.
