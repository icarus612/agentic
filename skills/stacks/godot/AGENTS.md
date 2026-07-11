# Godot — stack instructions

Conventions, tooling, and defaults for Godot 4 / GDScript projects. Godot code is
statically typed, node references are wired through `@export`/`%UniqueName`, game
data lives in `.tres` Custom Resources, and signals are connected in code for
traceability. Scripts are verified headlessly rather than through the editor.

## Rules
- **gdscript-standards** — static typing everywhere; `@export`/`%` node refs over
  `get_node`; data-driven `.tres` Custom Resources; connect signals in code.

## Skills
- **run-godot-test** — run a scene/script headlessly (`godot --headless`) to
  sanity-check logic without opening the editor.
- **generate-hex-neighbors** — canonical axial hex neighbor offsets and a
  `get_neighbors` helper (generic hex math, no game rules).
