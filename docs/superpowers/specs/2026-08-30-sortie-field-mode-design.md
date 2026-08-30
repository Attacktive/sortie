# Sortie — Field Mode Design Spec

- **Date:** 2026-08-30
- **Status:** Approved, not yet implemented
- **Engine:** Godot 4.7.2 stable, GDScript
- **Precedes:** `2026-08-30-sortie-design.md` built the battle; this builds the mode the battle will eventually be launched from

## 1. Purpose

Sortie's story mode is a JRPG, not a wrapper around battles.
The player spends most of their time walking a character around a world, talking to people, and tripping events; battles are what punctuate that.

The battle slice is therefore a component the story mode will call into, not the spine of the game.

This spec covers **field mode only**: a map you can walk around.
Its job is to get a character moving on a map correctly, with collision that feels right and rules that stay testable, before anything is built on top of it.

**Done means:** you run `godot scenes/field.tscn`, walk around with the arrow keys, cannot walk through walls, slide along them instead of catching on them, the character faces where it is going, the camera follows and stops at the map edge, and the headless suite covers all of it.

**Explicit non-goals for this sub-project:** NPCs, dialogue, interaction, event triggers, world state, battle handoff, save/load, story content, new art, and changing the game's main scene.
Each is a later sub-project with its own spec.

## 2. Where this sits

"Story mode" is at least six projects.
They have a dependency order, and this is the first.

| # | Sub-project | Delivers |
|---|---|---|
| **1** | **Field mode** *(this spec)* | A walkable map |
| 2 | Interaction and dialogue | Face something, press accept, a text box with a speaker |
| 3 | Events and world state | Triggers on step / interact / enter, and flags that remember |
| 4 | Mode flow and battle handoff | Title → field → battle → field, with the field restored |
| 5 | Save and load | Once there is world state worth keeping |
| 6 | Content | The map, the people, the writing |

Sub-project 4 is where `run/main_scene` finally changes.
Until then the field is a scene you run directly, and `battle.tscn` remains what the project launches.

## 3. Architecture

The same two layers and the same single bridge as the battle.

**`core/` — the rules.**
Plain `RefCounted`.
No `Node`, no scene tree, no rendering, no input.
Movement and collision are decided here, which is the whole reason this sub-project is testable at all.

**`scenes/` — the presentation.**
Reads input, asks `core/` where the character ends up, puts it there, and animates it.

Both existing grep invariants must still pass after this work:

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/     # must be empty
grep -rlE 'randf|randi|randomize' core/ | grep -v real_roll_source  # must be empty
```

### New files

| Path | Responsibility |
|---|---|
| `core/facing.gd` | The four LPC sheet rows, and which one a direction implies |
| `core/field_map.gd` | Map size, which tiles are solid, ASCII construction |
| `core/field_body.gd` | The movement sweep: where a box ends up given a velocity |
| `scenes/field.gd` | Owns the map, the view, the player, and the camera |
| `scenes/field_view.gd` | Draws the map's tiles |
| `scenes/field_player.gd` | Input → velocity, `FieldBody.move()`, position, animation |

### Modified files

| Path | Change |
|---|---|
| `scenes/unit_view.gd` | `Facing` and `_facing_for()` move to `core/facing.gd`; `UnitView` uses them from there |
| `test/test_terrain_art.gd` | The two facing tests move to the new core suite |
| `scenes/screenshot_probe.gd` | Learns to capture the field, so movement can be verified visually |

## 4. Facing

Facing is currently owned by `UnitView`, in `scenes/`.
Field mode needs exactly the same four-row mapping, so it moves to `core/facing.gd` and both modes share one definition rather than keeping two in sync.

```gdscript
class_name Facing
extends RefCounted

enum Direction { UP, LEFT, DOWN, RIGHT }

static func from_vector(direction: Vector2, current: Direction) -> Direction
```

The enum's integer values are the LPC sheet's row indices, because `_draw()` selects a row with `int(facing)`.
This is a contract, not a listing order, and the existing test that pins it moves across with the enum.

Battle movement is one axis at a time, so it never had to resolve a diagonal.
Field movement is eight-directional against four-directional art, so:

- The dominant axis picks the row: `abs(x) > abs(y)` gives `LEFT`/`RIGHT`, otherwise `UP`/`DOWN`.
- An exact diagonal keeps `current`.

That second rule exists because a perfect diagonal has no dominant axis.
Without it, running diagonally flickers between two sheet rows every frame.

A zero vector also keeps `current`: stopping does not turn you around.

## 5. The movement model

### Signature

```gdscript
class_name FieldBody
extends RefCounted

## Returns where the box ends up after moving at this velocity for this long.
static func move(box: Rect2, velocity: Vector2, delta: float, map: FieldMap) -> Rect2
```

Pure, deterministic, and Node-free.
`scenes/field_player.gd` holds none of this; it converts input to a velocity, calls this, and applies the result.

### Axis separation

The sweep resolves X fully, then resolves Y, each against the solid tiles the box overlaps after that axis has moved.

This ordering is the design, not an implementation detail.
It is what produces **wall-sliding**: walking north-east into a north wall cancels the northward component while the eastward component survives, so the character slides along the wall instead of stopping dead.
It is also why inside corners do not catch — each axis is judged on its own, so being blocked on one never blocks the other.

Resolution on a blocked axis snaps the box flush against the offending tile's edge rather than reverting the whole step, so a character always ends up touching the wall they walked into.

### Sub-stepping

If a single frame's movement would exceed half a tile on either axis, the move is split into equal sub-steps of at most half a tile and each is resolved in turn.

At the design speed a frame moves 1.6 px and tunneling is impossible.
The guard is for the frame that hitches — a delta spike, a breakpoint, a laptop waking up — where a single step could carry the box clean through a wall.
That failure is invisible in normal play, unreproducible when reported, and free to prevent here.

### The collision box

The box is the character's **feet**, not the sprite: 32 wide by 20 tall, centered horizontally on the 64×64 sprite and flush with its bottom edge.

This is the top-down convention, and it is load-bearing for how the world reads.
A full-sprite box holds the character two tiles away from anything above them.
A feet box lets the head overlap the tile above, so a character can stand *behind* a tree or a wall rather than being fenced off from it.

### Constants

| Constant | Value | Why |
|---|---|---|
| `SPEED` | `96.0` px/s | 1.5 tiles per second; brisk without being twitchy. One number, tuned by feel later. |
| `BOX_SIZE` | `Vector2(32, 20)` | See above |
| `MAX_STEP` | `GridGeometry.CELL_SIZE * 0.5` | The sub-stepping threshold |
| `BOX_OFFSET` | `Vector2(16, 44)` | Where the box sits inside the sprite; see below |

### The one conversion

`FieldBody.move()` takes and returns a `Rect2` — the feet box — because that is what collides.
The sprite is drawn from its top-left corner.
The two are related by exactly one constant, in exactly one place:

```gdscript
box.position = sprite_position + BOX_OFFSET      # (64 - 32) / 2 = 16 across, 64 - 20 = 44 down
sprite_position = box.position - BOX_OFFSET
```

Nothing else in the codebase may convert between them.
This is the mitigation for the two-coordinate-systems risk in section 10, and it is why `move()` returns a box rather than a position: the node converts once, on the way out, instead of the rules layer guessing what a "position" means.

## 6. The map

`FieldMap` mirrors `BattleGrid`'s best property: it is built from ASCII, so every test declares its world as a picture.

```gdscript
class_name FieldMap
extends RefCounted

static func from_ascii(rows: PackedStringArray) -> FieldMap

func is_solid(cell: Vector2i) -> bool
func solid_tiles_overlapping(box: Rect2) -> Array[Vector2i]
```

`.` is walkable, `#` is solid, `F` is a tree — walkable or not is a per-glyph property, and trees are solid here even though a battle forest is enterable.
Tiles outside the map's bounds are solid, so the edge of the world needs no special case anywhere else.

Cells are `GridGeometry.CELL_SIZE`, the same 64 px as the battle, and the field reuses the three existing terrain textures.
New field art is a content problem for sub-project 6, not this one.

## 7. Presentation

`scenes/field_view.gd` draws the map's tiles, reusing the battle's per-cell grass-variant hash so a large field does not read as a checkerboard.

`scenes/field_player.gd` each frame:

1. Reads `ui_up` / `ui_down` / `ui_left` / `ui_right` into a direction vector, normalized so diagonals are not faster.
2. Multiplies by `SPEED` and calls `FieldBody.move()`.
3. Converts the returned box back to a sprite position with `BOX_OFFSET` and applies it.
4. Asks `Facing.from_vector()` for its row, and plays the LPC walk cycle while moving or holds frame 0 while still.

The walk animation is the one already driving battle units — four directions, nine frames — so field mode inherits it outright.

A `Camera2D` follows the player with its limits set to the map's pixel bounds, so it stops at the edges instead of showing the void beyond them.
The viewport is 730×600, which is smaller than any map worth walking around, so the camera is required rather than optional.

## 8. Testing

### `core/`, headless

- `Facing`: all eight directions resolve to the correct row; an exact diagonal keeps the current facing; a zero vector keeps the current facing; the enum's integers are still the LPC row order.
- `FieldMap`: ASCII construction, per-glyph solidity, out-of-bounds is solid, box-to-tile overlap.
- `FieldBody`: walking into a wall stops flush against it from all four directions; a diagonal into a wall slides along it; inside corners do not catch; a delta large enough to cross a wall in one step cannot tunnel through it; the same inputs always produce the same path.

### Through real input

The harness added in PR #6 transfers directly.
Real `InputEventKey` objects pushed through `get_viewport().push_input()` must show the character actually moving, facing correctly, and animating — the layer that would otherwise go unverified, and where this project's bugs have historically lived.

### Visually

`scenes/screenshot_probe.gd` gains a field capture, so the walk cycle can be checked frame by frame the way the battle's was.
A single capture proves a frame drew; a series proves a cycle plays.

### Regression

All 136 existing tests must still pass.
The facing refactor touches battle code and must change no battle behavior.

## 9. Error handling

`FieldMap.from_ascii()` asserts that every row is the same length, matching `BattleGrid`'s behavior — a ragged map is an authoring mistake and should fail loudly at construction rather than produce a world with holes in it.

`FieldBody.move()` never asserts.
A character starting inside a wall — which content mistakes will produce — resolves outward rather than trapping the player or crashing, because a stuck character is worse than a slightly wrong one.

## 10. Open risks

**The feet box may read as wrong against 64 px tiles.**
LPC characters are drawn for roughly 32 px terrain, so on 64 px tiles a character occupies a single cell exactly.
A 32×20 feet box is a starting value, not a measured one, and is likely to need adjusting once someone walks around with it.
It is two numbers in one constant.

**Free movement is a departure from the tile model.**
Everything else in this project addresses the world in cells.
Field mode is the first place a position is a float, and the two coordinate systems have to stay honest with each other — particularly for sub-project 2, where "which tile am I facing" decides what you can talk to.
Keeping `FieldMap` cell-addressed and the body pixel-addressed, with one conversion in one place, is the mitigation.

**Speed and camera behavior cannot be verified by testing.**
Both are feel, and feel needs a person.
The tests will prove the character moves where it should; whether 96 px/s is pleasant is a question only playing it answers.
