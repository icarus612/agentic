---
name: generate-hex-neighbors
description: Compute the six adjacent hex coordinates on an axial grid — use for any hex-grid neighbor, distance, or adjacency math in Godot.
type: stack
domain: godot
rules: [gdscript-standards]
model: sonnet
model-fallback: [gemini-pro]
---

# generate-hex-neighbors

Generic hex-grid math for Godot. Use **axial coordinates** `(q, r)` represented as
`Vector2i(q, r)` for grid logic and positioning — not offset or square-grid
coordinates.

## Neighbor offsets

The six axial direction vectors and a helper that returns a hex's neighbors:

```gdscript
const HEX_DIRECTIONS: Array[Vector2i] = [
    Vector2i(1, 0),
    Vector2i(1, -1),
    Vector2i(0, -1),
    Vector2i(-1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1),
]

func get_neighbors(hex: Vector2i) -> Array[Vector2i]:
    var neighbors: Array[Vector2i] = []
    for dir in HEX_DIRECTIONS:
        neighbors.append(hex + dir)
    return neighbors
```

Always use these canonical offsets — never hardcode individual neighbor
positions; call `get_neighbors` instead.

## Cube conversion & distance

For distance or line-drawing math, convert axial `(q, r)` to cube coordinates
`(q, r, s)` where `s = -q - r`:

```gdscript
func axial_to_cube(hex: Vector2i) -> Vector3i:
    return Vector3i(hex.x, hex.y, -hex.x - hex.y)

func hex_distance(a: Vector2i, b: Vector2i) -> int:
    var ac: Vector3i = axial_to_cube(a)
    var bc: Vector3i = axial_to_cube(b)
    return maxi(maxi(absi(ac.x - bc.x), absi(ac.y - bc.y)), absi(ac.z - bc.z))
```
