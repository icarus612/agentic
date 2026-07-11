---
name: gdscript-standards
description: Godot 4 / GDScript conventions — static typing, node refs, data-driven resources, code-connected signals.
type: rule
domain: godot
---

# Godot 4 & GDScript standards

- **Static typing everywhere.** Annotate every variable, parameter, and return
  type. `var health: int = 10`, `func move(target: Vector2i) -> void:` — never
  untyped `var health = 10` or `func move(target):`.
- **Node references via `@export` or `%UniqueName`.** Wire nodes with
  `@export var sprite: Sprite2D` or `@onready var label: Label = %StatusLabel`.
  Never hardcode paths with `get_node("Path/To/Node")`.
- **Data-driven design.** Define blueprints, stats, abilities, and level configs
  as Godot Custom Resources (`.tres`) instead of hardcoding data inside scripts.
- **Connect signals in code.** Use `button.pressed.connect(_on_button_pressed)`
  rather than Editor inspector connections, for traceability.
