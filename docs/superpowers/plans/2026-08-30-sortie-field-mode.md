# Field Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Walk a character around a map, with collision that stops you at walls and slides you along them.

**Architecture:** Movement and collision live in `core/` as pure functions over a `Rect2` and a map of solid tiles, resolved one axis at a time. `scenes/` reads input, calls into `core/`, and draws the result. No physics server, no `CharacterBody2D`, so walking is testable headless like every other rule in this project.

**Tech Stack:** Godot 4.7.2 stable, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-08-30-sortie-field-mode-design.md`

## Global Constraints

These apply to every task below.

- **Indent with tabs.** Never spaces.
- **Never hard-wrap for length.** One sentence per physical line, comments included. Soft wrapping exists.
- **A multiline expression is followed by an empty line** before the next statement. No empty line after an opening brace or `:`.
- **Prefer `if` over the ternary operator.**
- **American English** in prose, comments, and identifiers.
- **`core/` stays free of the scene tree.** After every task, both invariants must produce no output:

  ```sh
  grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
  grep -rlE 'randf|randi|randomize' core/ | grep -v real_roll_source
  ```

  The first one greps comments too, so a `core/` file cannot use the word "Node" even to explain that it does not depend on one.
  That is the price of an invariant blunt enough to be unfoolable, and it is cheaper than a grep clever enough to be wrong.

- **All 136 existing tests must keep passing.** Run the full suite, not just the new file:

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
  ```

- **A new `.gd` file needs its `.uid` committed.** Run `godot --headless --import` before `git add`; the repo tracks them.
- **Commits use `feat`/`fix`/`test`/`docs`.** Add the trailer `Co-authored-by: Claude Opus 5 <noreply@anthropic.com>`.
- **Do not change `run/main_scene`.** It stays `res://scenes/battle.tscn` until sub-project 4.

---

### Task 1: Facing moves into `core/`

**Files:**

- Create: `core/facing.gd`
- Create: `test/test_facing.gd`
- Modify: `scenes/unit_view.gd`
- Modify: `test/test_terrain_art.gd` (remove the two facing tests, which move to `test_facing.gd`)

**Interfaces:**

- Produces: `Facing.Direction` (enum `{ UP, LEFT, DOWN, RIGHT }`), `Facing.from_motion(direction: Vector2, current: Facing.Direction) -> Facing.Direction`, `Facing.toward(offset: Vector2) -> Facing.Direction`

`UnitView.Facing` and `UnitView._facing_for()` disappear. Every later task in this plan uses `Facing.Direction`.

- [ ] **Step 1: Write the failing test**

Create `test/test_facing.gd`:

```gdscript
extends GutTest

## _draw() picks a sheet row with int(facing), so the enum's integer values are the LPC row order itself, not an arbitrary listing.
## Reordering it would silently turn every character the wrong way.
func test_the_values_are_the_lpc_row_order() -> void:
	assert_eq(int(Facing.Direction.UP), 0, "row 0 of an LPC sheet faces away from the camera")
	assert_eq(int(Facing.Direction.LEFT), 1, "row 1 of an LPC sheet faces left")
	assert_eq(int(Facing.Direction.DOWN), 2, "row 2 of an LPC sheet faces the camera")
	assert_eq(int(Facing.Direction.RIGHT), 3, "row 3 of an LPC sheet faces right")

func test_motion_picks_the_dominant_axis() -> void:
	assert_eq(Facing.from_motion(Vector2(1, 0), Facing.Direction.UP), Facing.Direction.RIGHT, "walking east faces right")
	assert_eq(Facing.from_motion(Vector2(-1, 0), Facing.Direction.UP), Facing.Direction.LEFT, "walking west faces left")
	assert_eq(Facing.from_motion(Vector2(0, -1), Facing.Direction.RIGHT), Facing.Direction.UP, "walking north faces up")
	assert_eq(Facing.from_motion(Vector2(0, 1), Facing.Direction.RIGHT), Facing.Direction.DOWN, "walking south faces down")

func test_a_shallow_diagonal_still_has_a_dominant_axis() -> void:
	assert_eq(Facing.from_motion(Vector2(10, 3), Facing.Direction.UP), Facing.Direction.RIGHT, "mostly east is east")
	assert_eq(Facing.from_motion(Vector2(3, -10), Facing.Direction.RIGHT), Facing.Direction.UP, "mostly north is north")

## Adding a direction is not changing your mind, so a tie leaves the character facing where they already were.
func test_an_exact_diagonal_keeps_the_current_facing() -> void:
	assert_eq(Facing.from_motion(Vector2(1, 1), Facing.Direction.RIGHT), Facing.Direction.RIGHT)
	assert_eq(Facing.from_motion(Vector2(1, 1), Facing.Direction.UP), Facing.Direction.UP)
	assert_eq(Facing.from_motion(Vector2(-1, 1).normalized(), Facing.Direction.LEFT), Facing.Direction.LEFT, "normalized input must tie too")

func test_standing_still_does_not_turn_you_around() -> void:
	assert_eq(Facing.from_motion(Vector2.ZERO, Facing.Direction.LEFT), Facing.Direction.LEFT)

## Aiming is a different question from moving, and a range-2 Mage can target a cell diagonally.
func test_aiming_resolves_a_diagonal_vertically() -> void:
	assert_eq(Facing.toward(Vector2(1, 1)), Facing.Direction.DOWN, "a tie aims vertically, as face_toward always has")
	assert_eq(Facing.toward(Vector2(1, -1)), Facing.Direction.UP)
	assert_eq(Facing.toward(Vector2(2, 1)), Facing.Direction.RIGHT, "a dominant axis still wins")
```

- [ ] **Step 2: Run it and watch it fail**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_facing.gd -gexit
```

Expected: failure — `Facing` is not a known identifier.

- [ ] **Step 3: Write `core/facing.gd`**

```gdscript
class_name Facing
extends RefCounted

## LPC sheet row order. Do not reorder: these are indices into the spritesheet.
enum Direction { UP, LEFT, DOWN, RIGHT }

## Which way a character walking along this vector should face.
## An exact diagonal keeps the current facing, because adding a direction is not the same as changing your mind, and neither is stopping.
static func from_motion(direction: Vector2, current: Direction) -> Direction:
	if absf(direction.x) > absf(direction.y):
		if direction.x > 0.0:
			return Direction.RIGHT

		return Direction.LEFT

	if absf(direction.y) > absf(direction.x):
		if direction.y > 0.0:
			return Direction.DOWN

		return Direction.UP

	return current

## Which way a character aiming at this offset should face.
## A tie resolves vertically, which is what battle characters have always done when a diagonal target is in range.
static func toward(offset: Vector2) -> Direction:
	if absf(offset.x) > absf(offset.y):
		if offset.x > 0.0:
			return Direction.RIGHT

		return Direction.LEFT

	if offset.y > 0.0:
		return Direction.DOWN

	return Direction.UP
```

- [ ] **Step 4: Run the test and watch it pass**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_facing.gd -gexit
```

Expected: 6 tests passing.

- [ ] **Step 5: Point `UnitView` at it**

In `scenes/unit_view.gd`, delete the local enum and `_facing_for()`, and change the four places that referred to them:

```gdscript
# Delete these:
#   enum Facing { UP, LEFT, DOWN, RIGHT }
#   static func _facing_for(step: Vector2i) -> Facing: ...

var _facing: Facing.Direction = Facing.Direction.DOWN

func face_toward(cell: Vector2i) -> void:
	var delta := cell - unit.cell
	if delta == Vector2i.ZERO:
		return

	_facing = Facing.toward(Vector2(delta))
	queue_redraw()

# In walk_path(), replace `var facing := _facing_for(step)` with:
	var facing := Facing.from_motion(Vector2(step), _facing)

# And the signature of _face:
func _face(facing: Facing.Direction) -> void:
```

- [ ] **Step 6: Remove the moved tests from `test/test_terrain_art.gd`**

Delete `test_facing_values_are_the_lpc_row_order` and `test_every_step_direction_picks_its_own_facing`, along with the comment block above the first. They now live in `test/test_facing.gd`.

- [ ] **Step 7: Run the whole suite**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
```

Expected: 140 tests, all passing. Battle behavior is unchanged — `face_toward` keeps its vertical tie-break, and path steps are single-axis so they never tie at all.

- [ ] **Step 8: Commit**

```sh
godot --headless --import
git add core/facing.gd core/facing.gd.uid test/test_facing.gd test/test_facing.gd.uid scenes/unit_view.gd test/test_terrain_art.gd
git commit
```

Message: `refactor: move Facing into core so both modes share one definition`

---

### Task 2: `FieldMap`

**Files:**

- Create: `core/field_map.gd`
- Create: `test/test_field_map.gd`

**Interfaces:**

- Consumes: `GridGeometry.CELL_SIZE` (64)
- Produces: `FieldMap.from_ascii(rows: PackedStringArray) -> FieldMap`, `FieldMap.size: Vector2i`, `FieldMap.is_solid(cell: Vector2i) -> bool`, `FieldMap.solid_tiles_overlapping(box: Rect2) -> Array[Vector2i]`, `FieldMap.pixel_size() -> Vector2`

- [ ] **Step 1: Write the failing test**

Create `test/test_field_map.gd`:

```gdscript
extends GutTest

## Maps are declared as pictures, the same trick BattleGrid uses, because a wall in the wrong place is obvious in a picture and invisible in a list of coordinates.
const ROOM := [
	"......",
	".#..#.",
	"..FF..",
	"......",
]

func _room() -> FieldMap:
	return FieldMap.from_ascii(PackedStringArray(ROOM))

func test_the_map_knows_its_size() -> void:
	assert_eq(_room().size, Vector2i(6, 4))

func test_pixel_size_is_cells_times_the_cell_size() -> void:
	assert_eq(_room().pixel_size(), Vector2(6 * 64, 4 * 64))

func test_glyphs_map_to_solidity() -> void:
	var map := _room()
	assert_false(map.is_solid(Vector2i(0, 0)), "a dot is walkable")
	assert_true(map.is_solid(Vector2i(1, 1)), "a hash is solid")
	assert_true(map.is_solid(Vector2i(2, 2)), "a field tree is solid, unlike a battle forest")

## The edge of the world needs no special case anywhere else if it is simply solid.
func test_everything_outside_the_map_is_solid() -> void:
	var map := _room()
	assert_true(map.is_solid(Vector2i(-1, 0)))
	assert_true(map.is_solid(Vector2i(0, -1)))
	assert_true(map.is_solid(Vector2i(6, 0)))
	assert_true(map.is_solid(Vector2i(0, 4)))

func test_a_box_inside_one_tile_touches_only_that_tile() -> void:
	var box := Rect2(Vector2(70, 70), Vector2(20, 20))
	assert_eq(_room().solid_tiles_overlapping(box), [Vector2i(1, 1)], "the box sits wholly inside the wall at (1, 1)")

func test_a_box_spanning_a_seam_reports_both_tiles() -> void:
	var box := Rect2(Vector2(120, 70), Vector2(20, 20))
	var touched := _room().solid_tiles_overlapping(box)
	assert_eq(touched.size(), 1, "only (1, 1) is solid; (2, 1) is open floor")
	assert_has(touched, Vector2i(1, 1))

func test_a_box_on_open_floor_reports_nothing() -> void:
	assert_eq(_room().solid_tiles_overlapping(Rect2(Vector2(10, 200), Vector2(20, 20))).size(), 0)

func test_the_map_remembers_which_glyph_was_authored() -> void:
	## A view has to tell a tree from a wall, and is_solid() only answers yes or no.
	var map := _room()
	assert_eq(map.glyph_at(Vector2i(1, 1)), FieldMap.WALL)
	assert_eq(map.glyph_at(Vector2i(2, 2)), FieldMap.TREE)
	assert_eq(map.glyph_at(Vector2i(0, 0)), "", "walkable ground has no glyph to draw over the grass")

## There is deliberately no test for the ragged-map assert.
## GDScript's assert() halts the engine rather than raising something catchable, so GUT cannot exercise it, and a test that asserts true to stand in for one only inflates the count.
## It was verified by hand instead: FieldMap.from_ascii(["....", "..", "...."]) fails with "row 1 is 2 wide but the map is 4".
```

Verify that assert by hand once, since no test can:

```sh
# A throwaway SceneTree script calling FieldMap.from_ascii(PackedStringArray(["....", "..", "...."]))
# must halt with: Assertion failed: row 1 is 2 wide but the map is 4; a ragged map has holes in it
```

- [ ] **Step 2: Run it and watch it fail**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_map.gd -gexit
```

Expected: failure — `FieldMap` is not a known identifier.

- [ ] **Step 3: Write `core/field_map.gd`**

```gdscript
class_name FieldMap
extends RefCounted

## The walkable world. Built from ASCII so a map reads as a picture in tests and in content.
##
## A tree is solid here even though a battle forest is enterable: the battle asks "can a unit stand on this", the field asks "can a body pass through it", and those are different questions about the same art.

const WALKABLE := "."
const WALL := "#"
const TREE := "F"

var size: Vector2i = Vector2i.ZERO

## The authored glyph per non-walkable cell, not merely a bool, because a view has to tell a tree from a wall.
var _glyphs: Dictionary[Vector2i, String] = {}

static func from_ascii(rows: PackedStringArray) -> FieldMap:
	var map := FieldMap.new()
	map.size = Vector2i(rows[0].length(), rows.size())

	for y in rows.size():
		var row := rows[y]
		assert(row.length() == map.size.x, "row %d is %d wide but the map is %d; a ragged map has holes in it" % [y, row.length(), map.size.x])

		for x in row.length():
			if row[x] != WALKABLE:
				map._glyphs[Vector2i(x, y)] = row[x]

	return map

## Outside the map counts as solid, so the edge of the world needs no special case anywhere else.
func is_solid(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return true

	return _glyphs.has(cell)

## What was authored at this cell. Empty outside the map, or on walkable ground.
func glyph_at(cell: Vector2i) -> String:
	if not _glyphs.has(cell):
		return ""

	return _glyphs[cell]

func pixel_size() -> Vector2:
	return Vector2(size) * float(GridGeometry.CELL_SIZE)

## Every solid tile the box touches. The caller resolves against these; this only reports them.
func solid_tiles_overlapping(box: Rect2) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var cell := float(GridGeometry.CELL_SIZE)

	var first := Vector2i(floori(box.position.x / cell), floori(box.position.y / cell))
	var last := Vector2i(floori((box.end.x - 0.001) / cell), floori((box.end.y - 0.001) / cell))

	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var candidate := Vector2i(x, y)
			if is_solid(candidate):
				found.append(candidate)

	return found
```

The `- 0.001` on `last` matters: a box whose right edge lands exactly on a tile boundary is touching the tile it ends at, not the one after it. Without it, a character standing flush against a wall reports the wall beyond it as well and can never move away.

- [ ] **Step 4: Run the test and watch it pass**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_map.gd -gexit
```

Expected: 8 tests passing.

- [ ] **Step 5: Confirm the invariant still holds**

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
```

Expected: no output.

- [ ] **Step 6: Commit**

```sh
godot --headless --import
git add core/field_map.gd core/field_map.gd.uid test/test_field_map.gd test/test_field_map.gd.uid
git commit
```

Message: `feat: add FieldMap, the walkable world as a picture`

---

### Task 3: `FieldBody` — axis-separated collision and sub-stepping

**Files:**

- Create: `core/field_body.gd`
- Create: `test/test_field_body.gd`

**Interfaces:**

- Consumes: `FieldMap.solid_tiles_overlapping()`, `GridGeometry.CELL_SIZE`
- Produces: `FieldBody.move(box: Rect2, velocity: Vector2, delta: float, map: FieldMap) -> Rect2`, `FieldBody.BOX_SIZE`, `FieldBody.BOX_OFFSET`, `FieldBody.SPEED`

**Task 4 was folded into this one during implementation.** The two cannot be separated: every "walk into a wall" test here drives a large velocity in a single step, which tunnels straight through the wall unless the move is sub-stepped. Splitting them put a task boundary where the first half cannot stand on its own.

- [ ] **Step 1: Write the failing test**

Create `test/test_field_body.gd`:

```gdscript
extends GutTest

## A room with a wall across the middle of the second row.
## Tiles are 64px, so tile (2, 1) spans x 128..192, y 64..128.
const ROOM := [
	"......",
	"..#...",
	"......",
	"......",
]

func _room() -> FieldMap:
	return FieldMap.from_ascii(PackedStringArray(ROOM))

## A feet box placed with its top-left at this pixel position.
func _box_at(position: Vector2) -> Rect2:
	return Rect2(position, FieldBody.BOX_SIZE)

func test_open_ground_moves_you_exactly_where_you_asked() -> void:
	var moved := FieldBody.move(_box_at(Vector2(10, 200)), Vector2(100, 0), 0.1, _room())
	assert_almost_eq(moved.position.x, 20.0, 0.001, "100 px/s for 0.1s is 10 px")
	assert_almost_eq(moved.position.y, 200.0, 0.001)

func test_walking_east_into_a_wall_stops_flush_against_it() -> void:
	## Wall tile (2, 1) starts at x = 128. A box ending there is touching it.
	var box := _box_at(Vector2(100, 80))
	var moved := FieldBody.move(box, Vector2(1000, 0), 1.0, _room())
	assert_almost_eq(moved.end.x, 128.0, 0.001, "the box stops with its right edge on the wall's left edge")

func test_walking_west_into_a_wall_stops_flush_against_it() -> void:
	var box := _box_at(Vector2(200, 80))
	var moved := FieldBody.move(box, Vector2(-1000, 0), 1.0, _room())
	assert_almost_eq(moved.position.x, 192.0, 0.001, "the wall's right edge")

func test_walking_south_into_a_wall_stops_flush_against_it() -> void:
	var box := _box_at(Vector2(140, 10))
	var moved := FieldBody.move(box, Vector2(0, 1000), 1.0, _room())
	assert_almost_eq(moved.end.y, 64.0, 0.001, "the wall's top edge")

func test_walking_north_into_a_wall_stops_flush_against_it() -> void:
	var box := _box_at(Vector2(140, 150))
	var moved := FieldBody.move(box, Vector2(0, -1000), 1.0, _room())
	assert_almost_eq(moved.position.y, 128.0, 0.001, "the wall's bottom edge")

## The point of resolving one axis at a time: being blocked on one must never block the other.
func test_a_diagonal_into_a_wall_slides_along_it() -> void:
	var box := _box_at(Vector2(140, 150))
	var moved := FieldBody.move(box, Vector2(200, -1000), 1.0, _room())

	assert_almost_eq(moved.position.y, 128.0, 0.001, "northward movement is stopped by the wall")
	assert_gt(moved.position.x, 140.0, "but eastward movement survives, which is the slide")

func test_the_map_edge_stops_you_like_any_other_wall() -> void:
	var moved := FieldBody.move(_box_at(Vector2(10, 200)), Vector2(-1000, 0), 1.0, _room())
	assert_almost_eq(moved.position.x, 0.0, 0.001, "you cannot walk out of the world")

func test_moving_away_from_a_wall_you_are_touching_works() -> void:
	## Regression: a box flush against a wall must not count that wall as blocking its retreat.
	var flush := Rect2(Vector2(128.0 - FieldBody.BOX_SIZE.x, 80), FieldBody.BOX_SIZE)
	var moved := FieldBody.move(flush, Vector2(-100, 0), 0.1, _room())
	assert_lt(moved.position.x, flush.position.x, "walking away from a wall you are touching has to move you")

## Spec section 9: move() never asserts, because content mistakes will place a body inside a wall and a trapped player is worse than a slightly wrong one.
func test_a_body_starting_inside_a_wall_is_not_trapped() -> void:
	var stuck := Rect2(Vector2(140, 80), FieldBody.BOX_SIZE)
	assert_gt(_room().solid_tiles_overlapping(stuck).size(), 0, "this box really does start inside the wall")

	var moved := FieldBody.move(stuck, Vector2(0, 400), 1.0, _room())

	assert_ne(moved.position, stuck.position, "a body inside a wall has to be able to get out of it")
	assert_eq(_room().solid_tiles_overlapping(moved).size(), 0, "and end up somewhere it is not inside one")

func test_zero_velocity_changes_nothing() -> void:
	var box := _box_at(Vector2(10, 200))
	assert_eq(FieldBody.move(box, Vector2.ZERO, 0.1, _room()), box)

func test_the_same_inputs_always_produce_the_same_result() -> void:
	var box := _box_at(Vector2(100, 80))
	var first := FieldBody.move(box, Vector2(300, -120), 0.25, _room())
	var second := FieldBody.move(box, Vector2(300, -120), 0.25, _room())
	assert_eq(first, second, "movement is a pure function; a replay must reproduce a path exactly")
```

- [ ] **Step 2: Run it and watch it fail**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_body.gd -gexit
```

Expected: failure — `FieldBody` is not a known identifier.

- [ ] **Step 3: Write `core/field_body.gd`**

```gdscript
class_name FieldBody
extends RefCounted

## Movement and collision for a body walking around a FieldMap.
##
## Pure and Node-free on purpose. The obvious Godot answer is CharacterBody2D and move_and_slide(), which would put this behavior inside the physics server where no headless test can see it. A top-down world with rectangular obstacles does not need any of what that buys, so the rules stay here with the rest of the rules.

## The collision box is the character's feet, not the sprite.
## A full-sprite box holds a character a whole tile away from anything above them; a feet box lets the head overlap the tile above, so you can stand behind a tree instead of being fenced off from it.
const BOX_SIZE := Vector2(32.0, 20.0)

## Where the box sits inside the 64x64 sprite: (64 - 32) / 2 across, 64 - 20 down.
## This is the only conversion between box space and sprite space in the codebase.
const BOX_OFFSET := Vector2(16.0, 44.0)

## 1.5 tiles per second. Brisk without being twitchy, and the one number to turn when it feels wrong.
const SPEED := 96.0

static func box_for_sprite(sprite_position: Vector2) -> Rect2:
	return Rect2(sprite_position + BOX_OFFSET, BOX_SIZE)

static func sprite_position_for(box: Rect2) -> Vector2:
	return box.position - BOX_OFFSET

## Where the box ends up after moving at this velocity for this long.
## Resolves X fully, then Y. That ordering is the design: being blocked on one axis must never block the other, which is what makes a character slide along a wall instead of stopping dead against it.
static func move(box: Rect2, velocity: Vector2, delta: float, map: FieldMap) -> Rect2:
	var moved := box
	moved = _sweep(moved, Vector2(velocity.x * delta, 0.0), map)
	moved = _sweep(moved, Vector2(0.0, velocity.y * delta), map)

	return moved

## One axis, one step. `motion` has exactly one non-zero component.
static func _sweep(box: Rect2, motion: Vector2, map: FieldMap) -> Rect2:
	if motion == Vector2.ZERO:
		return box

	var moved := Rect2(box.position + motion, box.size)
	var blockers := map.solid_tiles_overlapping(moved)
	if blockers.is_empty():
		return moved

	var cell := float(GridGeometry.CELL_SIZE)

	for tile in blockers:
		var solid := Rect2(Vector2(tile) * cell, Vector2(cell, cell))

		if motion.x > 0.0:
			moved.position.x = minf(moved.position.x, solid.position.x - box.size.x)
		elif motion.x < 0.0:
			moved.position.x = maxf(moved.position.x, solid.end.x)
		elif motion.y > 0.0:
			moved.position.y = minf(moved.position.y, solid.position.y - box.size.y)
		else:
			moved.position.y = maxf(moved.position.y, solid.end.y)

	return moved
```

- [ ] **Step 4: Run the test and watch it pass**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_body.gd -gexit
```

Expected: 13 tests passing, including the two from the folded Task 4. If `test_moving_away_from_a_wall_you_are_touching_works` fails, the cause is the boundary case in `solid_tiles_overlapping` — check the `- 0.001` from Task 2 is present.

- [ ] **Step 5: Prove the slide test bites**

Temporarily change `move()` to return `box` unchanged when either axis is blocked, in place of the two `_sweep` calls:

```gdscript
	var moved := _sweep(Rect2(box.position + velocity * delta, box.size), Vector2.ZERO, map)
	if not map.solid_tiles_overlapping(Rect2(box.position + velocity * delta, box.size)).is_empty():
		return box

	return Rect2(box.position + velocity * delta, box.size)
```

Run the file. Expected: `test_a_diagonal_into_a_wall_slides_along_it` fails, because a blocked axis now cancels the whole step. **Revert the change.** A wall-sliding test that passes without axis separation is not testing anything.

- [ ] **Step 6: Commit**

```sh
godot --headless --import
git add core/field_body.gd core/field_body.gd.uid test/test_field_body.gd test/test_field_body.gd.uid
git commit
```

Message: `feat: add FieldBody, axis-separated movement in core`

---

### Task 4: Folded into Task 3

Sub-stepping shipped as part of Task 3, and this task no longer exists on its own.

The plan originally scheduled it separately, on the theory that a working sweep came first and the tunneling guard was a refinement layered on top.
That was wrong. Task 3's tests walk into walls at 1000 px/s over a full second, which is 1000 px in one step, and a sweep only inspects where the box lands rather than what it passed over — so without sub-stepping the box sails clean past the wall and clamps against an out-of-bounds tile far beyond it.
Six of Task 3's own tests failed until sub-stepping existed.

The lesson is about task boundaries rather than about collision: a task has to be the smallest unit that can pass its own tests, and this split was drawn somewhere the first half could not stand up alone.

---

### Task 5: `FieldView` — draw the map

**Files:**

- Create: `scenes/field_view.gd`
- Create: `test/test_field_view.gd`

**Interfaces:**

- Consumes: `FieldMap`, `GridView.PLAIN_VARIANTS`, `GridView.plain_variant_for()`
- Produces: `FieldView.map`, `FieldView.SOLID_TEXTURES`, `FieldView.layers_for()`

Reuses the battle's terrain art and its per-cell grass-variant hash, so a large field does not read as a checkerboard. New field art is sub-project 6.

**Done.** The shape held; four things about it did not, and they are written up at the end of the task.

- [ ] **Step 1: Write the failing test**

Create `test/test_field_view.gd`:

```gdscript
extends GutTest

## What is worth testing about a view is what it decides to draw.
## Whether those pixels actually landed is the screenshot probe's job in Task 8, and nothing headless can stand in for it.

func _view() -> FieldView:
	var view := FieldView.new()
	view.map = FieldMap.from_ascii(PackedStringArray(["..#.", ".FF.", "...."]))
	add_child_autofree(view)

	return view

func test_every_solid_glyph_has_art() -> void:
	for glyph in [FieldMap.WALL, FieldMap.TREE]:
		assert_true(FieldView.SOLID_TEXTURES.has(glyph), "glyph '%s' can be authored but has nothing to draw" % glyph)
		assert_true(ResourceLoader.exists(FieldView.SOLID_TEXTURES[glyph]), "glyph '%s' points at a texture that is not there" % glyph)

## Putting the view in the tree draws it for real, and GUT fails a test on any error raised while it runs, so this covers _draw as well as the layering.
func test_a_solid_tile_is_drawn_on_top_of_grass() -> void:
	var view := _view()
	await get_tree().process_frame

	var grass := view.layers_for(Vector2i(0, 0))
	var wall := view.layers_for(Vector2i(2, 0))
	var tree := view.layers_for(Vector2i(1, 1))

	assert_eq(grass.size(), 1, "walkable ground is grass and nothing else")
	assert_eq(wall.size(), 2, "a wall is grass with a wall on top of it, not a wall instead of grass")
	assert_true(GridView.PLAIN_VARIANTS.has(wall[0].resource_path), "the layer under a wall has to be grass, and grass is whichever variant the hash picked for that cell")
	assert_ne(wall[1], tree[1], "a tree that draws like a wall is a map you cannot read")
```

- [ ] **Step 2: Run it and watch it fail**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_view.gd -gexit
```

Expected: failure — `FieldView` is not a known identifier, so the script does not even parse.

- [ ] **Step 3: Write `scenes/field_view.gd`**

```gdscript
class_name FieldView
extends Node2D

## Draws a FieldMap.
##
## Reuses the battle's terrain art, including its per-cell grass hash, so a field big enough to walk around does not read as a checkerboard.
## Field-specific art is sub-project 6; until then the two modes are literally looking at the same tiles.

## Only the solid glyphs. Walkable ground is not in here because it is not one texture: it is whichever grass variant the hash picks for that cell.
const SOLID_TEXTURES := {
	FieldMap.WALL: "res://assets/lpc/terrain/wall.png",
	FieldMap.TREE: "res://assets/lpc/terrain/forest.png",
}

var map: FieldMap = null

var _solids: Dictionary[String, Texture2D] = {}
var _plains: Array[Texture2D] = []

func _ready() -> void:
	## Integer upscaling of 16px art into a 64px cell; anything but NEAREST turns it to mush.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	for glyph in SOLID_TEXTURES:
		_solids[glyph] = load(SOLID_TEXTURES[glyph])

	for path in GridView.PLAIN_VARIANTS:
		_plains.append(load(path))

	queue_redraw()

## Everything that goes on one cell, bottom first.
## Grass always, then the solid tile over it rather than instead of it, so a tree keeps its transparent edges.
##
## This is the whole of what the view decides; _draw only puts it on screen. Keeping the decision out here is what lets a headless test see it.
func layers_for(cell: Vector2i) -> Array[Texture2D]:
	var layers: Array[Texture2D] = [_plains[GridView.plain_variant_for(cell)]]

	if map.is_solid(cell):
		layers.append(_texture_for(cell))

	return layers

func _draw() -> void:
	if map == null:
		return

	var size := float(GridGeometry.CELL_SIZE)

	for y in map.size.y:
		for x in map.size.x:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * size, Vector2(size, size))

			for layer in layers_for(cell):
				draw_texture_rect(layer, rect, false)

## An unrecognized glyph draws as a wall: a tile you can see and cannot walk through is a bug, but a tile you cannot see and cannot walk through is a haunting. 👻
func _texture_for(cell: Vector2i) -> Texture2D:
	var glyph := map.glyph_at(cell)
	if _solids.has(glyph):
		return _solids[glyph]

	return _solids[FieldMap.WALL]
```

`FieldMap.glyph_at()` already exists from Task 2, which is why this task adds nothing to `core/`.

- [ ] **Step 4: Run the test and watch it pass**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_view.gd -gexit
```

Expected: 2 tests passing. Whole suite: 163.

- [ ] **Step 5: Commit**

```sh
godot --headless --import
git add scenes/field_view.gd scenes/field_view.gd.uid test/test_field_view.gd test/test_field_view.gd.uid
git commit
```

Message: `feat: draw a FieldMap with the battle's terrain art`

#### What changed from the plan as written, and why

**`GLYPH_TEXTURES` became `SOLID_TEXTURES`, and lost its walkable entry.** The dictionary as planned mapped `FieldMap.WALKABLE` to `plain_a.png`, and nothing ever read it: walkable ground is drawn from `GridView.PLAIN_VARIANTS` through the hash, so it is one of three textures and never reliably that one. A constant that states a falsehood and is never used is worse than no constant, and the test that walked over it was checking a fact about itself rather than about the view.

**The layering rule moved out of `_draw` into `layers_for()`.** The first pass drew grass and then the solid tile inline, and a mutation that deleted the solid layer outright passed every test — a map of invisible walls, which is exactly the failure the fallback comment jokes about. `_draw` cannot be inspected from a headless test, so anything it alone decides is untested by construction. Now `_draw` is a loop with no opinions and the opinion lives in a function a test can call. The last uninspectable step is `draw_texture_rect` itself, and that is what Task 8's screenshot is for.

**A third test was written and then deleted.** It asserted the `draw` signal fires. The signal fires whether or not `_draw` succeeds, so it proved a fact about Godot; what actually catches a broken `_draw` is GUT failing a test on any error raised during it, which the remaining test already gets by putting the view in the tree.

**One test was wrong while the code was right**, for the second time in this plan. It asserted that the grass under a wall at (2,0) matches the grass at (0,0) — contradicting the very variant hash the view exists to use. Corrected to assert the layer under a wall is *some* grass variant.

Verified by mutation, four for four: solid tiles all drawing as walls, a runtime error inside `_draw`, the solid layer never appended, and the solid tile layered underneath the grass instead of over it. Each one fails a test.

---

### Task 6: `FieldPlayer` — input, movement, animation

**Files:**

- Create: `scenes/field_player.gd`
- Create: `test/test_field_player.gd`

**Interfaces:**

- Consumes: `FieldBody.move()`, `FieldBody.box_for_sprite()`, `FieldBody.sprite_position_for()`, `FieldBody.SPEED`, `Facing.from_motion()`, `UnitView.WALK_FRAMES`, `UnitView.WALK_FPS`
- Produces: `FieldPlayer.map`, `FieldPlayer.setup(sheet_path: String)`, `FieldPlayer.facing`, `FieldPlayer.WALK_LOOP_FIRST`

The frame-advance loop is deliberately not shared with `UnitView`; see the spec's "On sharing the sprite animation".

**Done.** Eight tests rather than six, and the wall test had to be rebuilt — the writeup at the end of the task says why.

- [ ] **Step 1: Write the failing test**

Create `test/test_field_player.gd`:

```gdscript
extends GutTest

## Real input, driven through Input rather than the viewport: Input.get_vector reads held action state and only parse_input_event updates it.
## push_input delivers a one-shot, which would leave get_vector reading zero on the very next frame.
##
## The collision rules underneath are covered exhaustively by test_field_body.gd. What is covered here is the wiring, which is the layer this project's bugs have actually lived in.

const ROOM := [
	"......",
	"......",
	"......",
	"......",
]

## A wall down column 2, so walking east from the left edge meets it whatever row you are standing in.
const CORRIDOR := [
	"..#...",
	"..#...",
	"..#...",
	"..#...",
]

const ARROWS := [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]

var _player: FieldPlayer

func before_each() -> void:
	_player = FieldPlayer.new()
	_player.map = FieldMap.from_ascii(PackedStringArray(ROOM))
	_player.setup("res://assets/lpc/units/vanguard_walkcycle.png")
	_player.position = Vector2(100, 100)
	add_child_autofree(_player)
	await get_tree().process_frame

## Held keys are global device state, so a test that ended without releasing one would walk the next test's character into a wall.
func after_each() -> void:
	for keycode in ARROWS:
		_release(keycode)

func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed

	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _hold(keycode: Key) -> void:
	_key(keycode, true)

func _release(keycode: Key) -> void:
	_key(keycode, false)

func _hold_for_frames(keycode: Key, frames: int) -> void:
	_hold(keycode)

	for i in frames:
		await get_tree().process_frame

	_release(keycode)
	await get_tree().process_frame

## Walks until the character stops making progress, however many frames that takes, and reports how many it took.
## A fixed frame count would be a bet on how fast the machine running the test is: 120 frames covers 81 px here and the wall below is 80 px away, so a machine one percent faster would never reach it and the assertion would pass without ever touching a wall.
func _walk_until_settled(keycode: Key) -> int:
	const BUDGET := 1200

	_hold(keycode)

	var frames := BUDGET

	for i in BUDGET:
		var before := _player.position
		await get_tree().process_frame

		if _player.position == before:
			frames = i + 1
			break

	_release(keycode)
	await get_tree().process_frame

	return frames

func test_holding_right_moves_the_character_east() -> void:
	var before := _player.position.x
	await _hold_for_frames(KEY_RIGHT, 10)

	assert_gt(_player.position.x, before, "holding a direction has to actually move you")
	assert_eq(_player.facing, Facing.Direction.RIGHT, "and turn you to face the way you are going")

func test_holding_up_moves_the_character_north() -> void:
	var before := _player.position.y
	await _hold_for_frames(KEY_UP, 10)

	assert_lt(_player.position.y, before, "up the screen is negative y")
	assert_eq(_player.facing, Facing.Direction.UP)

func test_releasing_everything_stops_the_character() -> void:
	await _hold_for_frames(KEY_RIGHT, 5)
	var settled := _player.position

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_player.position, settled, "a released key must not leave you coasting")

## Letting go is not a change of mind. A character who snaps back to facing the camera the instant you stop reads as a twitch.
func test_letting_go_does_not_turn_you_around() -> void:
	await _hold_for_frames(KEY_RIGHT, 10)

	assert_eq(_player.facing, Facing.Direction.RIGHT, "you go on facing the way you were walking")

## Exact, not merely "did not pass through", because the exact number is the one that proves the sprite-to-box conversion was applied.
## Feed FieldBody the sprite position instead of the collision box and the character still stops at the wall, just sixteen pixels into it.
func test_a_wall_stops_the_character_with_its_feet_against_it() -> void:
	_player.map = FieldMap.from_ascii(PackedStringArray(CORRIDOR))
	_player.position = Vector2(0, 100)

	var frames := await _walk_until_settled(KEY_RIGHT)
	var flush := 2.0 * GridGeometry.CELL_SIZE - FieldBody.BOX_SIZE.x - FieldBody.BOX_OFFSET.x

	assert_almost_eq(_player.position.x, flush, 0.001, "walking east into a wall has to settle with the feet touching it; this settled after %d frames" % frames)

func test_stopping_returns_to_the_idle_frame() -> void:
	await _hold_for_frames(KEY_RIGHT, 20)

	assert_eq(_player._frame, 0, "frame 0 of an LPC walk sheet is the idle pose, and standing still rests on it")

## Read while still walking, because _hold_for_frames lets go at the end and letting go is what puts the idle frame back.
func test_walking_advances_past_the_idle_frame() -> void:
	_hold(KEY_RIGHT)
	await get_tree().process_frame
	await get_tree().process_frame

	var walking := _player._frame
	_release(KEY_RIGHT)

	assert_gt(walking, 0, "a walk cycle that never leaves frame 0 is not animating")

## Task 7 builds the player and hands it a map on separate lines, so there is at least one frame where it has none.
func test_a_player_without_a_map_stands_still() -> void:
	_player.map = null
	var before := _player.position

	await _hold_for_frames(KEY_RIGHT, 10)

	assert_eq(_player.position, before, "a player waiting for its map has to stand still rather than fall through the world")
```

- [ ] **Step 2: Run it and watch it fail**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_player.gd -gexit
```

Expected: failure — `FieldPlayer` is not a known identifier, so the script does not parse and GUT reports that nothing ran.

- [ ] **Step 3: Write `scenes/field_player.gd`**

```gdscript
class_name FieldPlayer
extends Node2D

## The character you walk around the field.
##
## Holds no movement logic of its own: it turns held input into a velocity, asks FieldBody where that lands, and puts itself there.
## Everything about how collision behaves lives in core/ and is tested there against the rules rather than against a running game.

## Frame 0 of an LPC walk sheet is the idle pose, so the walk cycle loops from 1 and standing still rests on 0.
const WALK_LOOP_FIRST := 1

var map: FieldMap = null
var facing: Facing.Direction = Facing.Direction.DOWN

var _sheet: Texture2D = null
var _frame: int = 0
var _elapsed: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup(sheet_path: String) -> void:
	_sheet = load(sheet_path)
	queue_redraw()

## No map means no world to collide against, which happens for the frame between building the player and handing it one.
func _process(delta: float) -> void:
	if map == null:
		return

	## Normalized, so a diagonal is not faster than an axis — and so an exact diagonal ties in Facing.from_motion, which is the tie it is written to keep the current facing through.
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	_step(direction, delta)
	_animate(direction, delta)

func _step(direction: Vector2, delta: float) -> void:
	if direction == Vector2.ZERO:
		return

	var box := FieldBody.box_for_sprite(position)
	var moved := FieldBody.move(box, direction * FieldBody.SPEED, delta, map)

	position = FieldBody.sprite_position_for(moved)
	_face(Facing.from_motion(direction, facing))

## Turning has to invalidate the sprite the moment it happens.
## Leaving it to the next walk frame would draw you facing the old way for up to a full frame of the walk cycle, which at 11 fps is long enough to see every time you round a corner.
func _face(turned: Facing.Direction) -> void:
	if turned == facing:
		return

	facing = turned
	queue_redraw()

func _animate(direction: Vector2, delta: float) -> void:
	if direction == Vector2.ZERO:
		_rest()
		return

	_elapsed += delta

	var cycle := UnitView.WALK_FRAMES - WALK_LOOP_FIRST
	var frame := WALK_LOOP_FIRST + int(_elapsed * UnitView.WALK_FPS) % cycle
	if frame == _frame:
		return

	_frame = frame
	queue_redraw()

## Standing still is the idle pose, and the cycle starts over from the beginning next time rather than resuming mid-stride.
func _rest() -> void:
	_elapsed = 0.0

	if _frame == 0:
		return

	_frame = 0
	queue_redraw()

func _draw() -> void:
	if _sheet == null:
		return

	var cell := float(GridGeometry.CELL_SIZE)
	var source := Rect2(_frame * cell, int(facing) * cell, cell, cell)

	draw_texture_rect_region(_sheet, Rect2(Vector2.ZERO, Vector2(cell, cell)), source)
```

`Input.get_vector()` returns a normalized vector, so a diagonal is not faster than an axis. That normalization is also what makes an exact diagonal tie in `Facing.from_motion()`.

- [ ] **Step 4: Run the test and watch it pass**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_player.gd -gexit
```

Expected: 8 tests passing. Whole suite: 171.

`Input.parse_input_event()` is used here rather than `get_viewport().push_input()` because `Input.get_vector()` reads held action state, which only `parse_input_event` updates. `push_input` delivers a one-shot event and would leave `get_vector()` returning zero on the very next frame.

- [ ] **Step 5: Prove the tests bite**

Six mutations, each reverted after running:

| Mutation | Result |
|---|---|
| Collision bypassed — `position += direction * FieldBody.SPEED * delta` | 1 failure |
| The sprite position passed to `FieldBody` as the collision box | 1 failure |
| Input ignored — `Input.get_vector(...)` replaced with `Vector2.RIGHT` | 3 failures |
| `_rest()` never restores frame 0 | 1 failure |
| The walk cycle written without `WALK_LOOP_FIRST +`, so it includes the idle frame | 1 failure |
| The `map == null` guard deleted | 1 failure |

- [ ] **Step 6: Commit**

```sh
godot --headless --import
git add scenes/field_player.gd scenes/field_player.gd.uid test/test_field_player.gd test/test_field_player.gd.uid
git commit
```

Message: `feat: walk a character around the field`

#### What changed from the plan as written, and why

**The wall test counted frames, and the count was a bet on how fast the machine is.** As planned it held east for 120 frames and asserted the character had not passed x=128. Measured in this harness, 120 frames is 0.844 s of summed delta — about 7 ms a frame — which at 96 px/s carries the character **81 px**. The wall is **80 px** away. A machine one percent faster never reaches the wall at all, and the assertion passes having tested nothing; and since travel is summed delta rather than frames, every machine gives a different answer.

It now holds east until the character stops making progress, however many frames that takes, with a 1200-frame budget as a stop rather than a schedule. On this machine it settles after 146.

**And it asserts the exact resting position rather than an inequality.** `2 * CELL_SIZE - BOX_SIZE.x - BOX_OFFSET.x` = 80: the wall's west face, less the box's width, less the box's offset inside the sprite. That number is the one that proves the sprite-to-box conversion was applied, because feeding `FieldBody` the raw sprite position still stops the character at the wall — just sixteen pixels inside it. The mutation table above is the evidence: that run reports 96.0 against an expected 80.0.

**`test_walking_advances_past_the_idle_frame` could not have passed as written.** It called `_hold_for_frames`, which releases the key and lets a frame elapse — and releasing is exactly what puts the idle frame back, so it would have asserted `0 > 0` against a correct implementation. The frame has to be read while the character is still walking.

**`test_standing_still_holds_the_idle_frame` was replaced.** It asserted `_frame == 0` on a freshly built player, which tests the initializer rather than any behavior. It is now `test_stopping_returns_to_the_idle_frame`: walk, let go, and land back on the idle pose.

**Turning now invalidates the sprite immediately.** The planned code set `facing` in `_step` and redrew only when the walk frame changed in `_animate`, so changing direction mid-stride drew the old direction until the next frame tick — up to a full frame of the walk cycle, which at 11 fps is about 90 ms, every time you round a corner. `_face()` mirrors `UnitView._face()` and redraws on the turn itself.

That timing is **not covered by a test, and cannot easily be**: the walk frame advances on its own, so a redraw happens within a frame or two regardless, and a headless test cannot freeze the cycle to observe the gap. It is on the list for the Task 8 screenshot.

**Two tests added** beyond the six. A player whose `map` is still null stands still instead of erroring — Task 7 builds the player and assigns its map on separate lines, so that frame exists. And letting go of a key does not turn the character around, which `Facing.from_motion` documents as a rule but which is actually enforced here by `_step` returning early.

**`texture_filter` was set in both `setup()` and `_ready()`.** It is now only in `_ready()`, which always runs.

---

### Task 7: The field scene and its camera

**Files:**

- Create: `scenes/field.gd`
- Create: `scenes/field.tscn`
- Create: `test/test_field.gd`

**Interfaces:**

- Consumes: `FieldView`, `FieldPlayer`, `FieldMap`
- Produces: `Field.MAP`, `Field.START_CELL`, `Field._player`, `Field._camera`

- [ ] **Step 1: Write the failing test**

Create `test/test_field.gd`:

```gdscript
extends GutTest

var _field: Field

func before_each() -> void:
	_field = load("res://scenes/field.tscn").instantiate()
	add_child_autofree(_field)
	await get_tree().process_frame

func test_the_field_puts_a_player_on_the_map() -> void:
	assert_not_null(_field._player, "there is someone to walk around as")
	assert_not_null(_field._player.map, "and they know what they are walking on")

func test_the_player_starts_somewhere_walkable() -> void:
	var start := _field._player.map.is_solid(Field.START_CELL)
	assert_false(start, "spawning inside a wall is the one placement that traps the player")

## The viewport is smaller than any map worth walking around, so the camera is required rather than decorative.
func test_the_camera_is_limited_to_the_map() -> void:
	var bounds := _field._player.map.pixel_size()

	assert_eq(_field._camera.limit_left, 0)
	assert_eq(_field._camera.limit_top, 0)
	assert_eq(_field._camera.limit_right, int(bounds.x), "the camera must stop at the map's edge, not show the void past it")
	assert_eq(_field._camera.limit_bottom, int(bounds.y))

func test_the_camera_follows_the_player() -> void:
	assert_eq(_field._camera.get_parent(), _field._player, "a camera that does not move with the player is not following anything")
```

- [ ] **Step 2: Run it and watch it fail**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field.gd -gexit
```

Expected: failure — `res://scenes/field.tscn` does not exist.

- [ ] **Step 3: Write `scenes/field.gd`**

```gdscript
class_name Field
extends Node2D

## The walkable world. Owns the map, what draws it, who walks on it, and the camera that follows them.
##
## This is field mode's whole bridge, and it is deliberately thin: no NPCs, no events, no way into a battle. Those attach here in later sub-projects.

## Bigger than the viewport on both axes, so the camera has something to do.
const MAP := [
	"##################",
	"#....F......F....#",
	"#..#............##",
	"#..#....####.....#",
	"#.......#..#.....#",
	"#..FF...#..#..F..#",
	"#.......####.....#",
	"#....#...........#",
	"##...#....F....###",
	"#................#",
	"#..F..........FF.#",
	"##################",
]

const START_CELL := Vector2i(2, 1)
const PLAYER_SHEET := "res://assets/lpc/units/vanguard_walkcycle.png"

var _map: FieldMap = null
var _view: FieldView = null
var _player: FieldPlayer = null
var _camera: Camera2D = null

func _ready() -> void:
	_map = FieldMap.from_ascii(PackedStringArray(MAP))

	_view = FieldView.new()
	_view.map = _map
	add_child(_view)

	_player = FieldPlayer.new()
	_player.map = _map
	_player.position = GridGeometry.cell_to_position(START_CELL)
	_player.setup(PLAYER_SHEET)
	add_child(_player)

	_camera = Camera2D.new()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(_map.pixel_size().x)
	_camera.limit_bottom = int(_map.pixel_size().y)
	_player.add_child(_camera)
	_camera.make_current()
```

- [ ] **Step 4: Write `scenes/field.tscn`**

Mirrors `scenes/battle.tscn`: a bare `Node2D` with the script attached, because everything is built in `_ready()`.

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/field.gd" id="1"]

[node name="Field" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 5: Run the test and watch it pass**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field.gd -gexit
```

Expected: 4 tests passing.

- [ ] **Step 6: Run the whole suite and the invariants**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
grep -rlE 'randf|randi|randomize' core/ | grep -v real_roll_source
```

Expected: 175 tests passing, and no output from either grep. (Task 6 delivered eight tests rather than the six planned, which is where the two extra come from.)

- [ ] **Step 7: Walk around in it**

```sh
godot scenes/field.tscn
```

Confirm by hand: the arrow keys move the character, walls stop them, a diagonal into a wall slides along it, the character faces where it is going, the walk cycle animates, and the camera follows and stops at the map edge. Note anything that feels wrong — speed and the feet box are both listed in the spec as unverifiable by testing.

- [ ] **Step 8: Commit**

```sh
godot --headless --import
git add scenes/field.gd scenes/field.gd.uid scenes/field.tscn test/test_field.gd test/test_field.gd.uid
git commit
```

Message: `feat: add the field scene, with a camera that follows`

---

### Task 8: Visual verification and the handoff

**Files:**

- Modify: `scenes/field.gd`
- Modify: `scenes/screenshot_probe.gd`
- Modify: `docs/HANDOFF.md`

**Interfaces:**

- Consumes: everything above
- Produces: `SORTIE_FIELD_WALK` support in the screenshot probe

A single capture proves a frame drew. A series proves a cycle plays. This is how every visual claim in this project has been checked rather than asserted, and it has caught three bugs of its own.

- [ ] **Step 1: Teach the probe to hold a direction**

In `scenes/screenshot_probe.gd`, add before the wait:

```gdscript
	if OS.has_environment("SORTIE_FIELD_WALK"):
		_hold_direction(OS.get_environment("SORTIE_FIELD_WALK"))
```

And add the method:

```gdscript
## "right", "up", "left", or "down": holds that direction so a capture lands mid-stride.
## Pair with SORTIE_WAIT to choose which frame of the walk cycle is caught.
func _hold_direction(direction: String) -> void:
	var event := InputEventAction.new()
	event.action = "ui_%s" % direction
	event.pressed = true

	Input.parse_input_event(event)
	Input.flush_buffered_events()
```

- [ ] **Step 2: Let the field host the probe**

In `scenes/field.gd`, at the end of `_ready()`, matching what `battle.gd` already does:

```gdscript
	if OS.has_environment("SORTIE_SHOT"):
		add_child(load("res://scenes/screenshot_probe.gd").new())
```

- [ ] **Step 3: Capture a walk cycle**

```sh
S=/tmp/field
mkdir -p "$S"
for w in 0.10 0.18 0.26 0.34 0.42 0.50; do
	SORTIE_SHOT="$S/walk_$w.png" SORTIE_FIELD_WALK=right SORTIE_WAIT=$w godot scenes/field.tscn --quit-after 600
done
```

- [ ] **Step 4: Confirm the captures are real frames**

```sh
for f in "$S"/walk_*.png; do
	echo "$f $(magick "$f" -format '%[fx:mean] %[fx:standard_deviation]' info:) $(wc -c < "$f")"
done
```

Expected: a non-zero mean and standard deviation for every file. **A mean of 0 with a standard deviation of 0 is a blank capture, not a passing test** — that exact failure is on the record in `docs/HANDOFF.md`.

Then look at them: the character's x position must increase across the series, the legs must change, and the facing row must be RIGHT throughout.

- [ ] **Step 5: Update `docs/HANDOFF.md`**

- Header: the test count, and that field mode exists.
- "Run it": `godot scenes/field.tscn`, and the `SORTIE_FIELD_WALK` capture recipe.
- "Done": a field mode section — the map, free movement resolved in `core/`, the feet box, sub-stepping, the camera.
- "Not done": replace nothing; add the remaining story-mode sub-projects 2 through 6 with the spec as their reference.
- "Map of the code": the six new files.
- "Known issues and risks": the feet box is an unmeasured guess, and 96 px/s is unverified by anything but playing.

- [ ] **Step 6: Commit**

```sh
git add scenes/screenshot_probe.gd scenes/field.gd docs/HANDOFF.md
git commit
```

Message: `docs: verify the field walk cycle and refresh the handoff`

---

## Done means

- `godot scenes/field.tscn` puts you on a map you can walk around with the arrow keys.
- Walls stop you flush, and a diagonal into a wall slides along it.
- The character faces where it is going and animates while moving.
- The camera follows and stops at the map's edge.
- The full suite passes headless, and both grep invariants produce no output.
- `run/main_scene` is untouched.
