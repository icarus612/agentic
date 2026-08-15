# Goal
Connect signals safely in GDScript to prevent runtime crashes.

# Instructions
1. **Avoid:** `node.connect("signal_name", self, "_method_name")` (Old style).
2. **Prefer:** `node.signal_name.connect(_method_name)` (Godot 4.x style).
3. **Custom Signals:** Always define signals at the top of the script with arguments typed: `signal health_changed(new_health: int)`.