# Grid Engine

The Milestone 2 grid engine is a reusable, gameplay-agnostic 2D grid for Godot 4.5.1. It supports rectangular boards where both axes are between 5 and 10 cells.

## Components

### `GridManager.gd`

`GridManager` owns dimensions, coordinate conversion, occupancy, touch hit-testing, selection, highlighting, debug overlays, and serialization. It extends `Node2D`, so its world conversion methods respect translation, rotation, and scale.

The occupancy map is stored as a flat row-major array. Lookup uses `y * width + x`, avoiding per-frame allocations and dictionary hashing. Touch input is handled once by the manager rather than by up to 100 cell controls.

Key methods:

- `configure(size, cell_size)` rebuilds the engine and clears all state.
- `grid_to_local_position`, `grid_to_world`, `local_to_grid`, and `world_to_grid` convert positions.
- `set_occupant`, `get_occupant`, `clear_occupant`, and `is_occupied` provide constant-time occupancy operations.
- `select_cell` and `highlight_cell` update visual state and selection signals.
- `serialize_grid` creates a JSON-safe versioned snapshot.
- `deserialize_grid` validates the entire snapshot before changing the active grid.

### `GridCell.gd`

`GridCell` is a lightweight `Node2D` renderer. It has no input or gameplay logic. Drawing is cached by Godot and invalidated only when occupancy, selection, highlighting, content, or flash state changes.

## Coordinate contract

Grid coordinates start at `(0, 0)` in the upper-left and increase right/down. `grid_to_*` returns cell centers by default. Conversion of positions outside the configured bounds returns `GridManager.INVALID_CELL`.

`world` means the 2D canvas coordinate space after the viewport canvas transform. Touch input converts viewport coordinates through the inverse canvas transform before world-to-grid conversion, so Camera2D remains supported.

## Serialization schema

Snapshots contain:

```json
{
  "version": 1,
  "size": [7, 7],
  "cell_size": 72.0,
  "selected": [2, 3],
  "occupancy": [
    {"cell": [1, 1], "occupant": {"kind": "arrow"}}
  ]
}
```

Occupant payloads support JSON primitives plus arrays, dictionaries, `StringName`, `Vector2`, `Vector2i`, and `Color`. Engine objects and resources are deliberately unsupported: save stable identifiers and reconstruct objects at the feature boundary.

## Arrow Escape integration

`Board.tscn` composes a `GridManager`. Board gameplay assigns arrow dictionaries as occupants, listens for `cell_selected`, checks directional paths through the occupancy API, and animates the selected `GridCell`. The grid engine contains no knowledge of arrows, levels, scoring, or saves.

## Debugging and tests

Run the automated unit-test scene:

```bash
godot --headless --path . --scene res://tests/grid/GridEngineUnitTest.tscn
```

Open `tests/grid/GridEngineDebug.tscn` in the editor for interactive size controls, touch/mouse selection, highlighting, occupancy toggles, coordinate labels, and JSON round trips.
