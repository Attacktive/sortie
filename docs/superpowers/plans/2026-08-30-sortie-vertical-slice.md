# Sortie Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable grid-tactics battle in Godot 4 — select a unit, move it across terrain, attack with hit/crit/variance rolls, survive an AI turn, and reach victory or defeat.

**Architecture:** Two layers with exactly one bridge. Everything under `core/` is plain `RefCounted`/`Resource` GDScript with no `Node` reference, so it runs and tests headless. Everything under `scenes/` and `ui/` renders core state and forwards input. `scenes/battle.gd` is the only script permitted to touch both.

**Tech Stack:** Godot 4.7.2 stable, GDScript, GUT 9.7.1 for tests.

**Spec:** `docs/superpowers/specs/2026-08-30-sortie-design.md`

## Global Constraints

- **Godot 4.7.2 stable**, GDScript only. No C# — the .NET toolchain is not installed.
- **`core/` must never reference a `Node`, a scene, or a global singleton.** No `preload` of `.tscn`, no `get_tree()`, no `Input`. If a core file needs one of these, the design is wrong — stop and report.
- **All randomness flows through an injected `RollSource`.** Core code must never call `randf()`, `randi()`, or `randomize()` directly. `RealRollSource` is the only place a `RandomNumberGenerator` exists.
- **`Combat.forecast()` is pure** — it mutates nothing and consumes zero rolls. This is asserted in tests, not merely intended.
- **Roll order is a contract:** hit, then crit, then variance, drawn in that order and consumed conditionally. A miss draws exactly one roll. Changing this invalidates saved seeds.
- **Indent with tabs.** Blank line after a multiline expression before the next statement. Never put an `if` body on the same line as the condition.
- **American English** in identifiers, comments, and commit messages.
- **Placeholder art only:** `ColorRect` and flat colors. No sprite assets in this slice.
- Every task ends with a commit. Commit messages use `feat:`, `test:`, `fix:`, `chore:`, `docs:` and end with the trailer `Co-authored-by: Claude Opus 5 <noreply@anthropic.com>`.
- Work happens on branch `feature/tactics-vertical-slice`.

## Refinements to the Spec

Two points the spec left underspecified. These are decisions, not open questions:

1. **Spec §5** describes `reachable_cells()` and `path_to()` as separate functions sharing one pass. Implemented as `Movement.field()` returning a `MovementField` object that holds the costs and predecessor map, with `reachable_cells()` and `path_to()` as methods on it. This delivers the spec's stated "one pass" property instead of re-flooding per call.
2. **Spec §8** says the AI's `KILL_BONUS` applies when "maximum damage would meet or exceed the target's current HP" without saying whether that maximum includes a crit. **Decision: non-crit `max_damage`.** The AI weights kills it can guarantee, not kills it would need luck for.

---

## File Structure

| File | Responsibility |
|---|---|
| `core/terrain.gd` | Terrain enum plus move cost / defense / evasion lookups |
| `core/unit_data.gd` | `Resource` holding a unit's stats and team |
| `core/battle_unit.gd` | Runtime unit state: hp, cell, has_acted |
| `core/battle_grid.gd` | Tiles, terrain, occupancy; ASCII construction for tests |
| `core/movement_field.gd` | One flood fill's results: costs and paths |
| `core/movement.gd` | Flood fill and attack-range geometry |
| `core/roll_source.gd` | Randomness contract, `roll_unit() -> [0.0, 1.0)` |
| `core/real_roll_source.gd` | Seeded `RandomNumberGenerator` |
| `core/scripted_roll_source.gd` | Queued literal rolls, for tests |
| `core/attack_forecast.gd` | Pure prediction: chances and damage bounds |
| `core/attack_result.gd` | Outcome of one resolved attack |
| `core/combat_exchange.gd` | An attack plus its optional counterattack |
| `core/combat.gd` | Forecast, resolution, exchange |
| `core/turn_order.gd` | Phase machine and victory/defeat detection |
| `core/ai_decision.gd` | One enemy's chosen move and target |
| `core/enemy_ai.gd` | Expected-value scoring and target selection |
| `scenes/battle.gd` | The single bridge: core queries, view calls, phase advance |
| `scenes/unit_view.gd` | Placeholder body, HP bar, path tween |
| `scenes/cursor.gd` | Keyboard and mouse cell selection |
| `ui/action_menu.gd` | Attack / Wait |
| `ui/forecast_panel.gd` | Formats floats to percentages for display |
| `ui/result_screen.gd` | Victory / Defeat, restart |

---

### Task 1: Project scaffold and a verified headless test run

Nothing else can be trusted until a test can fail for the right reason. This task's deliverable is a green headless run of a deliberately trivial test.

**Files:**
- Create: `project.godot`
- Create: `addons/gut/` (vendored, from the pinned release)
- Create: `test/test_harness.gd`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing
- Produces: the test command every later task uses —
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`

- [ ] **Step 1: Create the branch**

```bash
git checkout -b feature/tactics-vertical-slice
```

- [ ] **Step 2: Write `project.godot`**

`run/main_scene` is deliberately absent — it gets added in Task 14, once a scene exists to point at.

```ini
config_version=5

[application]

config/name="Sortie"
config/features=PackedStringArray("4.7", "GL Compatibility")

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")

[rendering]

renderer/rendering_method="gl_compatibility"
```

- [ ] **Step 3: Vendor GUT at a pinned version**

GUT is committed to the repo rather than fetched at build time, so the test suite is reproducible without a network.

```bash
curl -sSL https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.zip -o /tmp/gut.zip
unzip -q /tmp/gut.zip -d /tmp/gut-extract
mkdir -p addons
cp -R /tmp/gut-extract/Gut-9.7.1/addons/gut addons/gut
rm -rf /tmp/gut.zip /tmp/gut-extract
test -f addons/gut/plugin.cfg && echo "GUT vendored"
```

A fresh project has no import cache, so GUT's `class_name` registrations do not exist yet and `gut_cmdln.gd` aborts with "Some GUT class_names have not been imported."
Run the import pass once after vendoring:

```bash
godot --headless --import
```

- [ ] **Step 4: Write a test that must fail**

```gdscript
extends GutTest

func test_harness_reports_failures() -> void:
	assert_eq(1, 2, "this failure is intentional — it proves the harness reports")
```

- [ ] **Step 5: Run it and confirm it FAILS**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: 1 test, 1 failing, non-zero exit code.

**If GUT errors out on Godot 4.7 instead of reporting a clean failure, stop and report it.** The fallback is gdUnit4, which changes the test command in every subsequent task — that is a plan revision, not something to improvise around.

- [ ] **Step 6: Flip the test to passing**

```gdscript
extends GutTest

func test_harness_reports_passes() -> void:
	assert_eq(1, 1, "the harness runs and reports")
```

- [ ] **Step 7: Run it and confirm it PASSES**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: 1 test, 1 passing, exit code 0.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "chore: scaffold Godot project with vendored GUT 9.7.1

Headless test run verified green on Godot 4.7.2.

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Terrain, UnitData, BattleUnit

**Files:**
- Create: `core/terrain.gd`, `core/unit_data.gd`, `core/battle_unit.gd`
- Create: `test/test_terrain.gd`, `test/test_battle_unit.gd`
- Delete: `test/test_harness.gd` (its job is done)

**Interfaces:**
- Consumes: nothing
- Produces:
  - `Terrain.Type` — enum `{ PLAIN, FOREST, WALL }`
  - `Terrain.move_cost(type: Type) -> int`
  - `Terrain.defense_bonus(type: Type) -> int`
  - `Terrain.evasion_bonus(type: Type) -> float`
  - `Terrain.is_passable(type: Type) -> bool`
  - `UnitData` — `Resource` with `Team` enum and stat fields
  - `BattleUnit.new(data: UnitData, cell: Vector2i)`, `.hp`, `.cell`, `.has_acted`, `.is_alive() -> bool`, `.team() -> UnitData.Team`

- [ ] **Step 1: Write the failing terrain test**

```gdscript
extends GutTest

func test_plain_costs_one_and_grants_nothing() -> void:
	assert_eq(Terrain.move_cost(Terrain.Type.PLAIN), 1)
	assert_eq(Terrain.defense_bonus(Terrain.Type.PLAIN), 0)
	assert_almost_eq(Terrain.evasion_bonus(Terrain.Type.PLAIN), 0.0, 0.0001)

func test_forest_costs_two_and_grants_cover() -> void:
	assert_eq(Terrain.move_cost(Terrain.Type.FOREST), 2)
	assert_eq(Terrain.defense_bonus(Terrain.Type.FOREST), 2)
	assert_almost_eq(Terrain.evasion_bonus(Terrain.Type.FOREST), 0.2, 0.0001)

func test_walls_are_impassable_and_everything_else_is_not() -> void:
	assert_false(Terrain.is_passable(Terrain.Type.WALL))
	assert_true(Terrain.is_passable(Terrain.Type.PLAIN))
	assert_true(Terrain.is_passable(Terrain.Type.FOREST))
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: FAIL — `Terrain` is not a known identifier.

- [ ] **Step 3: Implement `core/terrain.gd`**

```gdscript
class_name Terrain
extends RefCounted

enum Type { PLAIN, FOREST, WALL }

const _MOVE_COST := {
	Type.PLAIN: 1,
	Type.FOREST: 2,
}

const _DEFENSE_BONUS := {
	Type.PLAIN: 0,
	Type.FOREST: 2,
}

const _EVASION_BONUS := {
	Type.PLAIN: 0.0,
	Type.FOREST: 0.2,
}

## Movement cost to enter a tile of this type.
## Impassable types have no meaningful cost; callers must check is_passable() first.
static func move_cost(type: Type) -> int:
	return _MOVE_COST.get(type, 1)

static func defense_bonus(type: Type) -> int:
	return _DEFENSE_BONUS.get(type, 0)

static func evasion_bonus(type: Type) -> float:
	return _EVASION_BONUS.get(type, 0.0)

static func is_passable(type: Type) -> bool:
	return type != Type.WALL
```

- [ ] **Step 4: Run the terrain test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: PASS.

- [ ] **Step 5: Write the failing unit test**

```gdscript
extends GutTest

func _make_data(max_hp: int) -> UnitData:
	var data := UnitData.new()
	data.unit_name = "Tester"
	data.max_hp = max_hp
	data.attack = 5
	data.defense = 1
	data.accuracy = 0.9
	data.evasion = 0.1
	data.crit_rate = 0.0
	data.move_range = 3
	data.attack_range = 1
	data.team = UnitData.Team.PLAYER

	return data

func test_unit_starts_at_full_health_on_its_cell() -> void:
	var unit := BattleUnit.new(_make_data(12), Vector2i(2, 3))
	assert_eq(unit.hp, 12)
	assert_eq(unit.cell, Vector2i(2, 3))
	assert_false(unit.has_acted)
	assert_true(unit.is_alive())

func test_unit_is_dead_at_zero_hp() -> void:
	var unit := BattleUnit.new(_make_data(12), Vector2i.ZERO)
	unit.hp = 0
	assert_false(unit.is_alive())

func test_unit_reports_its_team() -> void:
	var unit := BattleUnit.new(_make_data(12), Vector2i.ZERO)
	assert_eq(unit.team(), UnitData.Team.PLAYER)
```

- [ ] **Step 6: Run it to verify it fails**

Expected: FAIL — `UnitData` is not a known identifier.

- [ ] **Step 7: Implement `core/unit_data.gd`**

```gdscript
class_name UnitData
extends Resource

enum Team { PLAYER, ENEMY }

@export var unit_name: String = "Unit"
@export var max_hp: int = 10
@export var attack: int = 5
@export var defense: int = 0

## Chance to land a hit before the defender's evasion is subtracted, in [0.0, 1.0].
@export_range(0.0, 1.0) var accuracy: float = 0.9
@export_range(0.0, 1.0) var evasion: float = 0.0
@export_range(0.0, 1.0) var crit_rate: float = 0.0

## Movement budget in accumulated terrain cost, not in tiles.
@export var move_range: int = 3

## Attack reach in Manhattan distance.
@export var attack_range: int = 1
@export var team: Team = Team.PLAYER

## Placeholder art only — no sprites in this slice.
@export var color: Color = Color.WHITE
```

- [ ] **Step 8: Implement `core/battle_unit.gd`**

```gdscript
class_name BattleUnit
extends RefCounted

var data: UnitData
var hp: int
var cell: Vector2i
var has_acted: bool = false

func _init(unit_data: UnitData, start_cell: Vector2i) -> void:
	data = unit_data
	hp = unit_data.max_hp
	cell = start_cell

func is_alive() -> bool:
	return hp > 0

func team() -> UnitData.Team:
	return data.team
```

- [ ] **Step 9: Run all tests to verify they pass**

Expected: PASS, all tests across both files.

- [ ] **Step 10: Delete the scaffold test and commit**

```bash
rm test/test_harness.gd
git add -A
git commit -m "feat: add terrain table, unit data, and runtime unit state

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: BattleGrid with ASCII construction

The ASCII builder is not a convenience — every movement, combat, and AI test in this plan declares its scenario as a picture. It is the single highest-leverage thing in the codebase for test readability.

**Files:**
- Create: `core/battle_grid.gd`
- Create: `test/test_battle_grid.gd`

**Interfaces:**
- Consumes: `Terrain`, `BattleUnit`, `UnitData` (Task 2)
- Produces:
  - `BattleGrid.from_ascii(rows: PackedStringArray) -> BattleGrid` — `.` plain, `F` forest, `#` wall
  - `.size: Vector2i`
  - `.is_in_bounds(cell: Vector2i) -> bool`
  - `.terrain_at(cell: Vector2i) -> Terrain.Type` — returns `WALL` when out of bounds
  - `.unit_at(cell: Vector2i) -> BattleUnit` — `null` when empty
  - `.place_unit(unit: BattleUnit, cell: Vector2i) -> void`
  - `.move_unit(unit: BattleUnit, to: Vector2i) -> void`
  - `.remove_unit(unit: BattleUnit) -> void`
  - `.living_units_of_team(team: UnitData.Team) -> Array[BattleUnit]`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

func _grid() -> BattleGrid:
	return BattleGrid.from_ascii(PackedStringArray([
		"..F.",
		".#..",
		"....",
	]))

func _unit(team: UnitData.Team) -> BattleUnit:
	var data := UnitData.new()
	data.max_hp = 10
	data.team = team

	return BattleUnit.new(data, Vector2i.ZERO)

func test_ascii_sets_size_and_terrain() -> void:
	var grid := _grid()
	assert_eq(grid.size, Vector2i(4, 3))
	assert_eq(grid.terrain_at(Vector2i(0, 0)), Terrain.Type.PLAIN)
	assert_eq(grid.terrain_at(Vector2i(2, 0)), Terrain.Type.FOREST)
	assert_eq(grid.terrain_at(Vector2i(1, 1)), Terrain.Type.WALL)

func test_out_of_bounds_reads_as_wall() -> void:
	var grid := _grid()
	assert_false(grid.is_in_bounds(Vector2i(-1, 0)))
	assert_false(grid.is_in_bounds(Vector2i(4, 0)))
	assert_eq(grid.terrain_at(Vector2i(-1, 0)), Terrain.Type.WALL)
	assert_eq(grid.terrain_at(Vector2i(99, 99)), Terrain.Type.WALL)

func test_placing_and_moving_updates_occupancy() -> void:
	var grid := _grid()
	var unit := _unit(UnitData.Team.PLAYER)
	grid.place_unit(unit, Vector2i(0, 0))
	assert_eq(grid.unit_at(Vector2i(0, 0)), unit)
	assert_eq(unit.cell, Vector2i(0, 0))

	grid.move_unit(unit, Vector2i(2, 2))
	assert_null(grid.unit_at(Vector2i(0, 0)))
	assert_eq(grid.unit_at(Vector2i(2, 2)), unit)
	assert_eq(unit.cell, Vector2i(2, 2))

func test_empty_cell_has_no_unit() -> void:
	assert_null(_grid().unit_at(Vector2i(3, 2)))

func test_living_units_of_team_excludes_the_dead() -> void:
	var grid := _grid()
	var alive := _unit(UnitData.Team.PLAYER)
	var dead := _unit(UnitData.Team.PLAYER)
	var enemy := _unit(UnitData.Team.ENEMY)
	grid.place_unit(alive, Vector2i(0, 0))
	grid.place_unit(dead, Vector2i(0, 2))
	grid.place_unit(enemy, Vector2i(3, 0))
	dead.hp = 0

	var players := grid.living_units_of_team(UnitData.Team.PLAYER)
	assert_eq(players.size(), 1)
	assert_eq(players[0], alive)
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL — `BattleGrid` is not a known identifier.

- [ ] **Step 3: Implement `core/battle_grid.gd`**

```gdscript
class_name BattleGrid
extends RefCounted

const _ASCII_TERRAIN := {
	".": Terrain.Type.PLAIN,
	"F": Terrain.Type.FOREST,
	"#": Terrain.Type.WALL,
}

var size: Vector2i = Vector2i.ZERO

var _terrain: Dictionary[Vector2i, Terrain.Type] = {}
var _units: Dictionary[Vector2i, BattleUnit] = {}

## Builds a grid from a picture of it: "." plain, "F" forest, "#" wall.
## Every row must be the same length.
static func from_ascii(rows: PackedStringArray) -> BattleGrid:
	assert(rows.size() > 0, "from_ascii needs at least one row")

	var grid := BattleGrid.new()
	var width := rows[0].length()
	grid.size = Vector2i(width, rows.size())

	for y in rows.size():
		assert(rows[y].length() == width, "row %d is %d wide, expected %d" % [y, rows[y].length(), width])

		for x in width:
			var symbol := rows[y][x]
			assert(_ASCII_TERRAIN.has(symbol), "unknown terrain symbol '%s' at (%d, %d)" % [symbol, x, y])
			grid._terrain[Vector2i(x, y)] = _ASCII_TERRAIN[symbol]

	return grid

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y

## Out-of-bounds cells read as WALL so movement is naturally bounded without extra checks.
func terrain_at(cell: Vector2i) -> Terrain.Type:
	if not is_in_bounds(cell):
		return Terrain.Type.WALL

	return _terrain.get(cell, Terrain.Type.PLAIN)

func unit_at(cell: Vector2i) -> BattleUnit:
	return _units.get(cell, null)

func place_unit(unit: BattleUnit, cell: Vector2i) -> void:
	assert(is_in_bounds(cell), "cannot place a unit out of bounds at %s" % cell)
	assert(unit_at(cell) == null, "cell %s is already occupied" % cell)

	_units[cell] = unit
	unit.cell = cell

func move_unit(unit: BattleUnit, to: Vector2i) -> void:
	assert(_units.get(unit.cell, null) == unit, "unit is not registered at its own cell %s" % unit.cell)
	assert(unit_at(to) == null, "cannot move onto occupied cell %s" % to)

	_units.erase(unit.cell)
	_units[to] = unit
	unit.cell = to

## Identity-checked and idempotent: erasing by cell alone would evict whoever
## moved onto the dead unit's old cell afterward.
func remove_unit(unit: BattleUnit) -> void:
	if _units.get(unit.cell, null) == unit:
		_units.erase(unit.cell)

func living_units_of_team(team: UnitData.Team) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in _units.values():
		if unit.team() == team and unit.is_alive():
			result.append(unit)

	return result
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add BattleGrid with ASCII construction for tests

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Movement flood fill and pathing

**Files:**
- Create: `core/movement_field.gd`, `core/movement.gd`
- Create: `test/test_movement.gd`

**Interfaces:**
- Consumes: `BattleGrid`, `BattleUnit`, `Terrain` (Tasks 2-3)
- Produces:
  - `Movement.field(grid: BattleGrid, unit: BattleUnit) -> MovementField`
  - `Movement.attackable_cells(grid: BattleGrid, from_cell: Vector2i, attack_range: int) -> Array[Vector2i]`
  - `Movement.manhattan(a: Vector2i, b: Vector2i) -> int`
  - `MovementField.can_reach(cell: Vector2i) -> bool`
  - `MovementField.cost_to(cell: Vector2i) -> int` — `-1` when unreachable
  - `MovementField.reachable_cells() -> Array[Vector2i]`
  - `MovementField.path_to(cell: Vector2i) -> Array[Vector2i]` — excludes the origin, empty when unreachable

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

func _data(move_range: int, team: UnitData.Team) -> UnitData:
	var data := UnitData.new()
	data.max_hp = 10
	data.move_range = move_range
	data.attack_range = 1
	data.team = team

	return data

func _place(grid: BattleGrid, cell: Vector2i, move_range: int, team: UnitData.Team) -> BattleUnit:
	var unit := BattleUnit.new(_data(move_range, team), cell)
	grid.place_unit(unit, cell)

	return unit

func test_range_is_bounded_by_movement_budget() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".....",
		".....",
		".....",
	]))
	var unit := _place(grid, Vector2i(0, 0), 2, UnitData.Team.PLAYER)
	var field := Movement.field(grid, unit)

	assert_true(field.can_reach(Vector2i(2, 0)), "two tiles east costs 2")
	assert_true(field.can_reach(Vector2i(1, 1)), "one east one south costs 2")
	assert_false(field.can_reach(Vector2i(3, 0)), "three tiles east costs 3")
	assert_eq(field.cost_to(Vector2i(2, 0)), 2)
	assert_eq(field.cost_to(Vector2i(3, 0)), -1)

func test_forest_costs_two_and_eats_the_budget() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".F..",
	]))
	var unit := _place(grid, Vector2i(0, 0), 2, UnitData.Team.PLAYER)
	var field := Movement.field(grid, unit)

	assert_eq(field.cost_to(Vector2i(1, 0)), 2, "entering forest costs 2")
	assert_false(field.can_reach(Vector2i(2, 0)), "no budget left to leave the forest")

func test_walls_are_impassable_and_force_a_detour() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".#.",
		"...",
	]))
	var unit := _place(grid, Vector2i(0, 0), 4, UnitData.Team.PLAYER)
	var field := Movement.field(grid, unit)

	assert_false(field.can_reach(Vector2i(1, 0)), "the wall itself is never reachable")
	assert_eq(field.cost_to(Vector2i(2, 0)), 4, "down, across twice, then back up — not the two-step direct line")

func test_a_wall_can_push_a_nearby_cell_out_of_budget() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".#.",
		"...",
	]))
	var unit := _place(grid, Vector2i(0, 0), 3, UnitData.Team.PLAYER)

	assert_false(Movement.field(grid, unit).can_reach(Vector2i(2, 0)), "two tiles away by sight, four by foot")

func test_enemies_block_movement_entirely() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		"....",
	]))
	var mover := _place(grid, Vector2i(0, 0), 3, UnitData.Team.PLAYER)
	_place(grid, Vector2i(1, 0), 3, UnitData.Team.ENEMY)
	var field := Movement.field(grid, mover)

	assert_false(field.can_reach(Vector2i(1, 0)), "cannot enter an enemy's cell")
	assert_false(field.can_reach(Vector2i(2, 0)), "cannot pass through an enemy")

func test_allies_are_passable_but_not_landable() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		"....",
	]))
	var mover := _place(grid, Vector2i(0, 0), 3, UnitData.Team.PLAYER)
	_place(grid, Vector2i(1, 0), 3, UnitData.Team.PLAYER)
	var field := Movement.field(grid, mover)

	assert_false(field.can_reach(Vector2i(1, 0)), "cannot stop on an ally")
	assert_true(field.can_reach(Vector2i(2, 0)), "but may walk through one")

func test_path_lists_steps_without_the_origin() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		"...",
	]))
	var unit := _place(grid, Vector2i(0, 0), 3, UnitData.Team.PLAYER)
	var path := Movement.field(grid, unit).path_to(Vector2i(2, 0))

	assert_eq(path, [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])

func test_unreachable_target_yields_an_empty_path() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".#.",
	]))
	var unit := _place(grid, Vector2i(0, 0), 3, UnitData.Team.PLAYER)

	assert_eq(Movement.field(grid, unit).path_to(Vector2i(2, 0)).size(), 0)

func test_attack_range_is_manhattan_and_stays_in_bounds() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		"...",
		"...",
		"...",
	]))
	var cells := Movement.attackable_cells(grid, Vector2i(0, 0), 1)

	assert_eq(cells.size(), 2, "a corner has only two orthogonal neighbors")
	assert_true(cells.has(Vector2i(1, 0)))
	assert_true(cells.has(Vector2i(0, 1)))

func test_attack_range_two_reaches_diagonals_and_straights() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		"...",
		"...",
		"...",
	]))
	var cells := Movement.attackable_cells(grid, Vector2i(1, 1), 2)

	assert_true(cells.has(Vector2i(0, 0)), "diagonal is Manhattan distance 2")
	assert_false(cells.has(Vector2i(1, 1)), "a unit does not attack its own cell")
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL — `Movement` is not a known identifier.

- [ ] **Step 3: Implement `core/movement_field.gd`**

```gdscript
class_name MovementField
extends RefCounted

## Accumulated movement cost for every cell the unit can pass through.
var costs: Dictionary[Vector2i, int] = {}

## Predecessor map, for reconstructing a path backward from any reached cell.
var previous: Dictionary[Vector2i, Vector2i] = {}

## Cells the unit may actually finish its move on.
## A cell can be in costs but not landable, which is how allies stay passable.
var landable: Dictionary[Vector2i, bool] = {}

var origin: Vector2i = Vector2i.ZERO

func can_reach(cell: Vector2i) -> bool:
	return landable.has(cell)

func cost_to(cell: Vector2i) -> int:
	if not landable.has(cell):
		return -1

	return costs[cell]

func reachable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in landable.keys():
		result.append(cell)

	return result

## Steps from the origin to the target, excluding the origin itself.
## Empty when the target cannot be reached.
func path_to(cell: Vector2i) -> Array[Vector2i]:
	if not landable.has(cell):
		return [] as Array[Vector2i]

	var reversed: Array[Vector2i] = []
	var current := cell
	while current != origin:
		reversed.append(current)
		current = previous[current]

	reversed.reverse()

	return reversed
```

- [ ] **Step 4: Implement `core/movement.gd`**

Dijkstra rather than breadth-first, because forest costs 2 and a plain detour can beat a direct forest crossing. The grids are tiny, so the naive "scan for the cheapest unvisited cell" is chosen for legibility over a heap.

```gdscript
class_name Movement
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
]

static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## Floods outward from the unit's cell, bounded by its movement budget.
## One pass yields both the reachable set and the path to every cell in it.
static func field(grid: BattleGrid, unit: BattleUnit) -> MovementField:
	var result := MovementField.new()
	result.origin = unit.cell
	result.costs[unit.cell] = 0
	result.landable[unit.cell] = true

	var budget := unit.data.move_range
	var visited: Dictionary[Vector2i, bool] = {}

	while true:
		var next_cell: Variant = _cheapest_unvisited(result.costs, visited)
		if next_cell == null:
			break

		var current: Vector2i = next_cell
		visited[current] = true

		for direction in DIRECTIONS:
			var neighbor: Vector2i = current + direction
			var terrain := grid.terrain_at(neighbor)
			if not Terrain.is_passable(terrain):
				continue

			var blocker := grid.unit_at(neighbor)
			if blocker != null and blocker.team() != unit.team():
				continue

			var cost: int = result.costs[current] + Terrain.move_cost(terrain)
			if cost > budget:
				continue

			if result.costs.has(neighbor) and result.costs[neighbor] <= cost:
				continue

			result.costs[neighbor] = cost
			result.previous[neighbor] = current
			visited.erase(neighbor)

			if blocker == null:
				result.landable[neighbor] = true
			else:
				result.landable.erase(neighbor)

	return result

## Returns null when every discovered cell has already been expanded.
## The caller must annotate the receiving variable as Variant explicitly:
## Godot 4.7 treats inferring a type from a Variant value as an error, so `:=` fails here.
static func _cheapest_unvisited(costs: Dictionary, visited: Dictionary) -> Variant:
	var best: Variant = null
	var best_cost := 0

	for cell in costs.keys():
		if visited.has(cell):
			continue

		var cost: int = costs[cell]
		if best == null or cost < best_cost:
			best = cell
			best_cost = cost

	return best

## Every in-bounds cell within Manhattan distance of the origin, excluding the origin.
static func attackable_cells(grid: BattleGrid, from_cell: Vector2i, attack_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for dy in range(-attack_range, attack_range + 1):
		for dx in range(-attack_range, attack_range + 1):
			var offset := Vector2i(dx, dy)
			if offset == Vector2i.ZERO:
				continue

			if absi(dx) + absi(dy) > attack_range:
				continue

			var cell: Vector2i = from_cell + offset
			if grid.is_in_bounds(cell):
				result.append(cell)

	return result
```

- [ ] **Step 5: Run tests to verify they pass**

Expected: PASS, all nine movement tests.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add movement flood fill with terrain costs and pathing

Dijkstra rather than BFS, since forest costs 2 and a plain detour can
be cheaper than crossing it. Allies are passable but not landable.

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: The RollSource family

**Files:**
- Create: `core/roll_source.gd`, `core/real_roll_source.gd`, `core/scripted_roll_source.gd`
- Create: `test/test_roll_source.gd`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `RollSource.roll_unit() -> float` — contract, returns a value in `[0.0, 1.0)`
  - `RealRollSource.new(seed_value: int)`
  - `ScriptedRollSource.new(rolls: Array[float])`, `.drawn() -> int`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

func test_scripted_returns_queued_rolls_in_order() -> void:
	var rolls := ScriptedRollSource.new([0.1, 0.5, 0.9] as Array[float])

	assert_almost_eq(rolls.roll_unit(), 0.1, 0.0001)
	assert_almost_eq(rolls.roll_unit(), 0.5, 0.0001)
	assert_almost_eq(rolls.roll_unit(), 0.9, 0.0001)

func test_scripted_counts_what_was_drawn() -> void:
	var rolls := ScriptedRollSource.new([0.1, 0.5] as Array[float])
	assert_eq(rolls.drawn(), 0)

	rolls.roll_unit()
	assert_eq(rolls.drawn(), 1)

func test_real_source_stays_in_the_half_open_unit_interval() -> void:
	var rolls := RealRollSource.new(12345)

	for i in 500:
		var value := rolls.roll_unit()
		assert_true(value >= 0.0, "roll %f dropped below 0.0" % value)
		assert_true(value < 1.0, "roll %f reached or exceeded 1.0" % value)

func test_same_seed_replays_the_same_sequence() -> void:
	var first := RealRollSource.new(999)
	var second := RealRollSource.new(999)

	for i in 20:
		assert_almost_eq(first.roll_unit(), second.roll_unit(), 0.0000001)

func test_different_seeds_diverge() -> void:
	var first := RealRollSource.new(1)
	var second := RealRollSource.new(2)
	var same := true

	for i in 20:
		if not is_equal_approx(first.roll_unit(), second.roll_unit()):
			same = false

	assert_false(same, "two different seeds produced an identical sequence")
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL — `ScriptedRollSource` is not a known identifier.

- [ ] **Step 3: Implement the three files**

```gdscript
# core/roll_source.gd
class_name RollSource
extends RefCounted

## Returns a float in [0.0, 1.0).
## The interval is half-open on purpose: a chance of 1.0 always succeeds and a chance of 0.0 never does,
## with no fencepost handling at either end.
func roll_unit() -> float:
	return 0.0
```

```gdscript
# core/real_roll_source.gd
class_name RealRollSource
extends RollSource

var _rng := RandomNumberGenerator.new()
var _seed: int = 0

func _init(seed_value: int) -> void:
	_seed = seed_value
	_rng.seed = seed_value

## The seed is exposed so a battle can log it and be replayed exactly.
func seed_value() -> int:
	return _seed

func roll_unit() -> float:
	return _rng.randf()
```

```gdscript
# core/scripted_roll_source.gd
class_name ScriptedRollSource
extends RollSource

var _rolls: Array[float] = []
var _index: int = 0

func _init(rolls: Array[float]) -> void:
	_rolls = rolls

func roll_unit() -> float:
	assert(_index < _rolls.size(), "ScriptedRollSource over-drawn: %d rolls queued, draw %d requested" % [_rolls.size(), _index + 1])

	var value := _rolls[_index]
	_index += 1

	return value

## How many rolls have been consumed, so tests can assert that a miss draws exactly one.
func drawn() -> int:
	return _index
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add injectable RollSource with seeded and scripted implementations

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Combat forecast (pure, no rolls)

The forecast is what the player reads before committing. It must be honest, and it must never consume randomness — otherwise merely looking at a target would change the battle.

**Files:**
- Create: `core/attack_forecast.gd`, `core/combat.gd`
- Create: `test/test_forecast.gd`

**Interfaces:**
- Consumes: `BattleGrid`, `BattleUnit`, `Terrain` (Tasks 2-3)
- Produces:
  - `Combat.CRIT_MULTIPLIER` = `3`, `Combat.DAMAGE_VARIANCE` = `0.1`
  - `Combat.forecast(grid: BattleGrid, attacker: BattleUnit, defender: BattleUnit) -> AttackForecast`
  - `AttackForecast.hit_chance: float`, `.crit_chance: float`, `.min_damage: int`, `.max_damage: int`, `.crit_damage: int`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

func _attacker_data() -> UnitData:
	var data := UnitData.new()
	data.max_hp = 20
	data.attack = 10
	data.defense = 0
	data.accuracy = 0.9
	data.evasion = 0.0
	data.crit_rate = 0.2
	data.attack_range = 1
	data.team = UnitData.Team.PLAYER

	return data

func _defender_data() -> UnitData:
	var data := UnitData.new()
	data.max_hp = 20
	data.attack = 4
	data.defense = 2
	data.accuracy = 0.8
	data.evasion = 0.1
	data.crit_rate = 0.0
	data.attack_range = 1
	data.team = UnitData.Team.ENEMY

	return data

## Two adjacent units on a one-row map whose terrain the caller chooses.
func _duel(row: String) -> Array:
	var grid := BattleGrid.from_ascii(PackedStringArray([row]))
	var attacker := BattleUnit.new(_attacker_data(), Vector2i(0, 0))
	var defender := BattleUnit.new(_defender_data(), Vector2i(1, 0))
	grid.place_unit(attacker, Vector2i(0, 0))
	grid.place_unit(defender, Vector2i(1, 0))

	return [grid, attacker, defender]

func test_hit_chance_subtracts_evasion() -> void:
	var duel := _duel("..")
	var forecast := Combat.forecast(duel[0], duel[1], duel[2])

	assert_almost_eq(forecast.hit_chance, 0.8, 0.0001, "0.9 accuracy minus 0.1 evasion")

func test_forest_lowers_hit_chance_and_damage_together() -> void:
	var duel := _duel(".F")
	var forecast := Combat.forecast(duel[0], duel[1], duel[2])

	assert_almost_eq(forecast.hit_chance, 0.6, 0.0001, "0.9 - (0.1 evasion + 0.2 forest)")
	assert_eq(forecast.min_damage, 5, "raw 6 at 0.9 variance rounds to 5")
	assert_eq(forecast.max_damage, 7, "raw 6 at 1.1 variance rounds to 7")

func test_damage_bounds_come_from_variance() -> void:
	var duel := _duel("..")
	var forecast := Combat.forecast(duel[0], duel[1], duel[2])

	assert_eq(forecast.min_damage, 7, "raw 8 at 0.9 variance rounds to 7")
	assert_eq(forecast.max_damage, 9, "raw 8 at 1.1 variance rounds to 9")

func test_crit_damage_is_the_maximum_tripled() -> void:
	var duel := _duel("..")
	var forecast := Combat.forecast(duel[0], duel[1], duel[2])

	assert_eq(forecast.crit_damage, 27, "9 maximum times the crit multiplier of 3")

func test_hit_chance_clamps_at_both_ends() -> void:
	var duel := _duel("..")
	var attacker: BattleUnit = duel[1]
	var defender: BattleUnit = duel[2]

	attacker.data.accuracy = 0.05
	defender.data.evasion = 0.9
	assert_almost_eq(Combat.forecast(duel[0], attacker, defender).hit_chance, 0.0, 0.0001, "never negative")

	attacker.data.accuracy = 1.0
	defender.data.evasion = 0.0
	assert_almost_eq(Combat.forecast(duel[0], attacker, defender).hit_chance, 1.0, 0.0001, "never above one")

func test_damage_never_forecasts_below_one() -> void:
	var duel := _duel("..")
	var attacker: BattleUnit = duel[1]
	var defender: BattleUnit = duel[2]
	attacker.data.attack = 3
	defender.data.defense = 10

	var forecast := Combat.forecast(duel[0], attacker, defender)
	assert_eq(forecast.min_damage, 1, "heavy armor still takes a scratch")
	assert_eq(forecast.max_damage, 1)

func test_forecast_mutates_nothing() -> void:
	var duel := _duel("..")
	var defender: BattleUnit = duel[2]
	var hp_before := defender.hp
	var cell_before := defender.cell

	Combat.forecast(duel[0], duel[1], defender)

	assert_eq(defender.hp, hp_before, "forecasting must not damage anyone")
	assert_eq(defender.cell, cell_before)
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL — `Combat` is not a known identifier.

- [ ] **Step 3: Implement `core/attack_forecast.gd`**

```gdscript
class_name AttackForecast
extends RefCounted

## Probability the attack connects, in [0.0, 1.0].
var hit_chance: float = 0.0

## Probability of a critical hit, given that the attack connects.
var crit_chance: float = 0.0

## Non-critical damage range produced by variance.
var min_damage: int = 0
var max_damage: int = 0

## What a maximum-variance critical hit would deal, for display.
var crit_damage: int = 0
```

- [ ] **Step 4: Implement `core/combat.gd` (forecast only)**

```gdscript
class_name Combat
extends RefCounted

const CRIT_MULTIPLIER := 3

## Damage swing as a fraction either side of raw damage.
## Set to 0.0 to remove variance entirely without touching any logic.
const DAMAGE_VARIANCE := 0.1

## Predicts an attack without rolling for it or mutating anything.
## This is what the player reads, so it must never lie and never consume a roll.
static func forecast(grid: BattleGrid, attacker: BattleUnit, defender: BattleUnit) -> AttackForecast:
	var result := AttackForecast.new()
	var terrain := grid.terrain_at(defender.cell)

	result.hit_chance = clampf(attacker.data.accuracy - (defender.data.evasion + Terrain.evasion_bonus(terrain)), 0.0, 1.0)
	result.crit_chance = attacker.data.crit_rate

	var raw := _raw_damage(grid, attacker, defender)
	result.min_damage = _apply_variance(raw, 1.0 - DAMAGE_VARIANCE)
	result.max_damage = _apply_variance(raw, 1.0 + DAMAGE_VARIANCE)
	result.crit_damage = result.max_damage * CRIT_MULTIPLIER

	return result

## Damage before variance and before the critical multiplier.
## Both terrain bonuses are read from the defender's cell.
static func _raw_damage(grid: BattleGrid, attacker: BattleUnit, defender: BattleUnit) -> int:
	var terrain := grid.terrain_at(defender.cell)

	return attacker.data.attack - (defender.data.defense + Terrain.defense_bonus(terrain))

## The floor of 1 lands here, before any critical multiplier, so a crit is always a clean 3x of the hit.
static func _apply_variance(raw: int, variance: float) -> int:
	return maxi(1, roundi(raw * variance))
```

- [ ] **Step 5: Run tests to verify they pass**

Expected: PASS, all eight forecast tests.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add pure combat forecast with terrain and variance bounds

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Combat resolution (hit, crit, variance)

**Files:**
- Create: `core/attack_result.gd`
- Modify: `core/combat.gd` (add `resolve`)
- Create: `test/test_combat.gd`

**Interfaces:**
- Consumes: `Combat.forecast` (Task 6), `RollSource` family (Task 5)
- Produces:
  - `Combat.resolve(grid, attacker, defender, rolls: RollSource) -> AttackResult`
  - `AttackResult.hit: bool`, `.crit: bool`, `.damage: int`, `.killed: bool`

- [ ] **Step 1: Write the failing test**

Every case scripts its rolls literally, so each test states the exact branch it exercises.

```gdscript
extends GutTest

func _duel(row: String) -> Array:
	var attacker_data := UnitData.new()
	attacker_data.max_hp = 20
	attacker_data.attack = 10
	attacker_data.accuracy = 0.9
	attacker_data.crit_rate = 0.2
	attacker_data.attack_range = 1
	attacker_data.team = UnitData.Team.PLAYER

	var defender_data := UnitData.new()
	defender_data.max_hp = 20
	defender_data.attack = 4
	defender_data.defense = 2
	defender_data.evasion = 0.1
	defender_data.crit_rate = 0.0
	defender_data.attack_range = 1
	defender_data.team = UnitData.Team.ENEMY

	var grid := BattleGrid.from_ascii(PackedStringArray([row]))
	var attacker := BattleUnit.new(attacker_data, Vector2i(0, 0))
	var defender := BattleUnit.new(defender_data, Vector2i(1, 0))
	grid.place_unit(attacker, Vector2i(0, 0))
	grid.place_unit(defender, Vector2i(1, 0))

	return [grid, attacker, defender]

func test_a_miss_deals_nothing_and_draws_exactly_one_roll() -> void:
	var duel := _duel("..")
	var rolls := ScriptedRollSource.new([0.85] as Array[float])

	var result := Combat.resolve(duel[0], duel[1], duel[2], rolls)

	assert_false(result.hit, "0.85 is not below the hit chance of 0.8")
	assert_eq(result.damage, 0)
	assert_eq(duel[2].hp, 20, "a miss leaves the defender untouched")
	assert_eq(rolls.drawn(), 1, "a miss must not draw the crit or variance rolls")

func test_a_hit_draws_exactly_three_rolls() -> void:
	var duel := _duel("..")
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5] as Array[float])

	Combat.resolve(duel[0], duel[1], duel[2], rolls)

	assert_eq(rolls.drawn(), 3, "hit, crit, variance")

func test_a_plain_hit_deals_raw_damage_at_mid_variance() -> void:
	var duel := _duel("..")
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5] as Array[float])

	var result := Combat.resolve(duel[0], duel[1], duel[2], rolls)

	assert_true(result.hit)
	assert_false(result.crit, "0.99 is not below the crit rate of 0.2")
	assert_eq(result.damage, 8, "attack 10 minus defense 2, at variance 1.0")
	assert_eq(duel[2].hp, 12)

func test_a_crit_triples_the_damage() -> void:
	var duel := _duel("..")
	var rolls := ScriptedRollSource.new([0.0, 0.0, 0.5] as Array[float])

	var result := Combat.resolve(duel[0], duel[1], duel[2], rolls)

	assert_true(result.crit)
	assert_eq(result.damage, 24, "8 tripled")

func test_the_crit_threshold_is_exclusive() -> void:
	var below := _duel("..")
	var at := _duel("..")

	var below_result := Combat.resolve(below[0], below[1], below[2], ScriptedRollSource.new([0.0, 0.1999, 0.5] as Array[float]))
	var at_result := Combat.resolve(at[0], at[1], at[2], ScriptedRollSource.new([0.0, 0.2, 0.5] as Array[float]))

	assert_true(below_result.crit, "0.1999 is below the crit rate of 0.2")
	assert_false(at_result.crit, "0.2 is not below 0.2")

func test_variance_reaches_both_bounds() -> void:
	var low := _duel("..")
	var high := _duel("..")

	var low_result := Combat.resolve(low[0], low[1], low[2], ScriptedRollSource.new([0.0, 0.99, 0.0] as Array[float]))
	var high_result := Combat.resolve(high[0], high[1], high[2], ScriptedRollSource.new([0.0, 0.99, 0.99999] as Array[float]))

	assert_eq(low_result.damage, 7, "raw 8 at 0.9 variance")
	assert_eq(high_result.damage, 9, "raw 8 at nearly 1.1 variance")

func test_a_hit_chance_of_one_always_connects() -> void:
	var duel := _duel("..")
	duel[1].data.accuracy = 1.0
	duel[2].data.evasion = 0.0
	var rolls := ScriptedRollSource.new([0.99999, 0.99, 0.5] as Array[float])

	assert_true(Combat.resolve(duel[0], duel[1], duel[2], rolls).hit, "roll_unit() never reaches 1.0")

func test_a_hit_chance_of_zero_never_connects() -> void:
	var duel := _duel("..")
	duel[1].data.accuracy = 0.0
	duel[2].data.evasion = 0.0
	var rolls := ScriptedRollSource.new([0.0] as Array[float])

	assert_false(Combat.resolve(duel[0], duel[1], duel[2], rolls).hit, "roll_unit() is never below 0.0")

func test_the_damage_floor_applies_before_the_crit_multiplier() -> void:
	var duel := _duel("..")
	duel[1].data.attack = 3
	duel[2].data.defense = 10
	var rolls := ScriptedRollSource.new([0.0, 0.0, 0.5] as Array[float])

	var result := Combat.resolve(duel[0], duel[1], duel[2], rolls)

	assert_true(result.crit)
	assert_eq(result.damage, 3, "the floor of 1, tripled — not a floored 1")

func test_forest_reduces_damage_through_defense() -> void:
	var duel := _duel(".F")
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5] as Array[float])

	assert_eq(Combat.resolve(duel[0], duel[1], duel[2], rolls).damage, 6, "attack 10 minus defense 2 plus forest 2")

func test_hp_never_falls_below_zero_and_a_kill_is_reported() -> void:
	var duel := _duel("..")
	duel[2].hp = 3
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5] as Array[float])

	var result := Combat.resolve(duel[0], duel[1], duel[2], rolls)

	assert_eq(duel[2].hp, 0, "8 damage against 3 hp stops at zero")
	assert_true(result.killed)
	assert_false(duel[2].is_alive())
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL — `Combat.resolve` does not exist.

- [ ] **Step 3: Implement `core/attack_result.gd`**

```gdscript
class_name AttackResult
extends RefCounted

var hit: bool = false
var crit: bool = false
var damage: int = 0

## True when this attack reduced the defender to zero hp.
var killed: bool = false
```

- [ ] **Step 4: Add `resolve` to `core/combat.gd`**

```gdscript
## Resolves one attack, drawing from rolls in a fixed order: hit, then crit, then variance.
## Rolls are consumed conditionally — a miss draws exactly one.
## This order is part of the contract: changing it invalidates every saved seed.
static func resolve(grid: BattleGrid, attacker: BattleUnit, defender: BattleUnit, rolls: RollSource) -> AttackResult:
	var result := AttackResult.new()
	var prediction := forecast(grid, attacker, defender)

	result.hit = rolls.roll_unit() < prediction.hit_chance
	if not result.hit:
		return result

	result.crit = rolls.roll_unit() < prediction.crit_chance

	var variance := 1.0 - DAMAGE_VARIANCE + rolls.roll_unit() * 2.0 * DAMAGE_VARIANCE
	var base := _apply_variance(_raw_damage(grid, attacker, defender), variance)

	var multiplier := 1
	if result.crit:
		multiplier = CRIT_MULTIPLIER

	result.damage = base * multiplier
	defender.hp = maxi(0, defender.hp - result.damage)
	result.killed = not defender.is_alive()

	return result
```

- [ ] **Step 5: Run tests to verify they pass**

Expected: PASS, all eleven combat tests.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: resolve attacks with hit, crit, and variance rolls

Rolls are drawn in a fixed order and consumed conditionally, so a miss
costs exactly one roll. The damage floor applies before the crit
multiplier, making a crit a clean 3x of the hit it replaces.

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: The counterattack exchange

**Files:**
- Create: `core/combat_exchange.gd`
- Modify: `core/combat.gd` (add `exchange`)
- Create: `test/test_exchange.gd`

**Interfaces:**
- Consumes: `Combat.resolve` (Task 7), `Movement.manhattan` (Task 4)
- Produces:
  - `Combat.exchange(grid, attacker, defender, rolls) -> CombatExchange`
  - `CombatExchange.attack: AttackResult`, `.counter: AttackResult` — `null` when no counter occurred

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

## Attacker at (0,0), defender placed at the given cell, on a wide-open row.
func _setup(defender_cell: Vector2i, attacker_range: int, defender_range: int) -> Array:
	var attacker_data := UnitData.new()
	attacker_data.max_hp = 20
	attacker_data.attack = 10
	attacker_data.accuracy = 0.9
	attacker_data.crit_rate = 0.0
	attacker_data.attack_range = attacker_range
	attacker_data.team = UnitData.Team.PLAYER

	var defender_data := UnitData.new()
	defender_data.max_hp = 20
	defender_data.attack = 6
	defender_data.defense = 2
	defender_data.evasion = 0.0
	defender_data.crit_rate = 0.0
	defender_data.attack_range = defender_range
	defender_data.team = UnitData.Team.ENEMY

	var grid := BattleGrid.from_ascii(PackedStringArray(["....."]))
	var attacker := BattleUnit.new(attacker_data, Vector2i(0, 0))
	var defender := BattleUnit.new(defender_data, defender_cell)
	grid.place_unit(attacker, Vector2i(0, 0))
	grid.place_unit(defender, defender_cell)

	return [grid, attacker, defender]

func test_a_surviving_defender_in_range_counters() -> void:
	var setup := _setup(Vector2i(1, 0), 1, 1)
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5, 0.0, 0.99, 0.5] as Array[float])

	var exchange := Combat.exchange(setup[0], setup[1], setup[2], rolls)

	assert_true(exchange.attack.hit)
	assert_not_null(exchange.counter, "an adjacent survivor strikes back")
	assert_true(exchange.counter.hit)
	assert_eq(exchange.counter.damage, 6, "defender attack 6 minus attacker defense 0")
	assert_eq(setup[1].hp, 14)
	assert_eq(rolls.drawn(), 6, "three rolls each")

func test_a_dead_defender_does_not_counter() -> void:
	var setup := _setup(Vector2i(1, 0), 1, 1)
	setup[2].hp = 2
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5] as Array[float])

	var exchange := Combat.exchange(setup[0], setup[1], setup[2], rolls)

	assert_true(exchange.attack.killed)
	assert_null(exchange.counter, "the dead do not retaliate")
	assert_eq(rolls.drawn(), 3, "no counter rolls are drawn")

func test_a_defender_out_of_its_own_range_does_not_counter() -> void:
	var setup := _setup(Vector2i(2, 0), 2, 1)
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5] as Array[float])

	var exchange := Combat.exchange(setup[0], setup[1], setup[2], rolls)

	assert_true(exchange.attack.hit)
	assert_null(exchange.counter, "reach 1 cannot answer an attack from two tiles away")
	assert_eq(rolls.drawn(), 3)

func test_a_missed_attack_still_draws_a_counter() -> void:
	var setup := _setup(Vector2i(1, 0), 1, 1)
	var rolls := ScriptedRollSource.new([0.95, 0.0, 0.99, 0.5] as Array[float])

	var exchange := Combat.exchange(setup[0], setup[1], setup[2], rolls)

	assert_false(exchange.attack.hit, "0.95 misses against a hit chance of 0.9")
	assert_not_null(exchange.counter, "whiffing does not protect you")
	assert_true(exchange.counter.hit)
	assert_eq(rolls.drawn(), 4, "one for the miss, three for the counter")

func test_the_counter_rolls_its_own_crit() -> void:
	var setup := _setup(Vector2i(1, 0), 1, 1)
	setup[2].data.crit_rate = 0.5
	var rolls := ScriptedRollSource.new([0.0, 0.99, 0.5, 0.0, 0.1, 0.5] as Array[float])

	var exchange := Combat.exchange(setup[0], setup[1], setup[2], rolls)

	assert_false(exchange.attack.crit)
	assert_true(exchange.counter.crit, "the counter draws independently")
	assert_eq(exchange.counter.damage, 18, "6 tripled")
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL — `Combat.exchange` does not exist.

- [ ] **Step 3: Implement `core/combat_exchange.gd`**

```gdscript
class_name CombatExchange
extends RefCounted

var attack: AttackResult

## Null when the defender died or could not reach the attacker.
var counter: AttackResult = null
```

- [ ] **Step 4: Add `exchange` to `core/combat.gd`**

```gdscript
## One full trade: the attack, then a counterattack if the defender survives and can reach back.
## The counter is a complete independent attack — its own hit, crit, and variance rolls.
static func exchange(grid: BattleGrid, attacker: BattleUnit, defender: BattleUnit, rolls: RollSource) -> CombatExchange:
	var result := CombatExchange.new()
	result.attack = resolve(grid, attacker, defender, rolls)

	if _can_counter(defender, attacker):
		result.counter = resolve(grid, defender, attacker, rolls)

	return result

static func _can_counter(defender: BattleUnit, attacker: BattleUnit) -> bool:
	if not defender.is_alive():
		return false

	return Movement.manhattan(defender.cell, attacker.cell) <= defender.data.attack_range
```

- [ ] **Step 5: Run tests to verify they pass**

Expected: PASS, all five exchange tests.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add counterattacks as fully independent attack rolls

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: Turn order and victory detection

**Files:**
- Create: `core/turn_order.gd`
- Create: `test/test_turn_order.gd`

**Interfaces:**
- Consumes: `BattleGrid`, `BattleUnit`, `UnitData` (Tasks 2-3)
- Produces:
  - `TurnOrder.Phase` — enum `{ PLAYER_TURN, ENEMY_TURN, VICTORY, DEFEAT }`
  - `TurnOrder.new(grid: BattleGrid)`, `.phase`, `.active_team() -> UnitData.Team`
  - `.units_awaiting_orders() -> Array[BattleUnit]`
  - `.should_end_turn() -> bool`
  - `.end_turn() -> void`
  - `.check_resolution() -> void`
  - `.is_over() -> bool`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

var _grid: BattleGrid

func _spawn(cell: Vector2i, team: UnitData.Team) -> BattleUnit:
	var data := UnitData.new()
	data.max_hp = 10
	data.team = team
	var unit := BattleUnit.new(data, cell)
	_grid.place_unit(unit, cell)

	return unit

func before_each() -> void:
	_grid = BattleGrid.from_ascii(PackedStringArray([
		"....",
		"....",
	]))

func test_battle_opens_on_the_player_turn() -> void:
	_spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	_spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	assert_eq(turns.phase, TurnOrder.Phase.PLAYER_TURN)
	assert_eq(turns.active_team(), UnitData.Team.PLAYER)
	assert_false(turns.is_over())

func test_the_turn_ends_once_every_unit_has_acted() -> void:
	var first := _spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	var second := _spawn(Vector2i(1, 0), UnitData.Team.PLAYER)
	_spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	assert_eq(turns.units_awaiting_orders().size(), 2)
	assert_false(turns.should_end_turn())

	first.has_acted = true
	assert_eq(turns.units_awaiting_orders().size(), 1)
	assert_false(turns.should_end_turn())

	second.has_acted = true
	assert_true(turns.should_end_turn())

func test_a_dead_unit_does_not_hold_up_the_turn() -> void:
	var alive := _spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	var doomed := _spawn(Vector2i(1, 0), UnitData.Team.PLAYER)
	_spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	alive.has_acted = true
	doomed.hp = 0

	assert_true(turns.should_end_turn(), "the dead are not awaiting orders")

func test_ending_a_turn_hands_over_and_clears_spent_flags() -> void:
	var player := _spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	var enemy := _spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	player.has_acted = true
	enemy.has_acted = true
	turns.end_turn()

	assert_eq(turns.phase, TurnOrder.Phase.ENEMY_TURN)
	assert_eq(turns.active_team(), UnitData.Team.ENEMY)
	assert_false(enemy.has_acted, "the incoming team is refreshed")
	assert_true(player.has_acted, "the outgoing team stays spent until its next turn")

	turns.end_turn()

	assert_eq(turns.phase, TurnOrder.Phase.PLAYER_TURN)
	assert_false(player.has_acted)

func test_wiping_out_the_enemy_is_victory() -> void:
	_spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	var enemy := _spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	enemy.hp = 0
	turns.check_resolution()

	assert_eq(turns.phase, TurnOrder.Phase.VICTORY)
	assert_true(turns.is_over())

func test_losing_every_unit_is_defeat() -> void:
	var player := _spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	_spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	player.hp = 0
	turns.check_resolution()

	assert_eq(turns.phase, TurnOrder.Phase.DEFEAT)
	assert_true(turns.is_over())

func test_a_resolved_battle_does_not_hand_over_turns() -> void:
	_spawn(Vector2i(0, 0), UnitData.Team.PLAYER)
	var enemy := _spawn(Vector2i(3, 0), UnitData.Team.ENEMY)
	var turns := TurnOrder.new(_grid)

	enemy.hp = 0
	turns.check_resolution()
	turns.end_turn()

	assert_eq(turns.phase, TurnOrder.Phase.VICTORY, "victory is terminal")
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL — `TurnOrder` is not a known identifier.

- [ ] **Step 3: Implement `core/turn_order.gd`**

```gdscript
class_name TurnOrder
extends RefCounted

enum Phase { PLAYER_TURN, ENEMY_TURN, VICTORY, DEFEAT }

var phase: Phase = Phase.PLAYER_TURN

var _grid: BattleGrid

func _init(grid: BattleGrid) -> void:
	_grid = grid

func is_over() -> bool:
	return phase == Phase.VICTORY or phase == Phase.DEFEAT

func active_team() -> UnitData.Team:
	if phase == Phase.ENEMY_TURN:
		return UnitData.Team.ENEMY

	return UnitData.Team.PLAYER

## Living units on the active team that have not yet spent their action.
func units_awaiting_orders() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in _grid.living_units_of_team(active_team()):
		if not unit.has_acted:
			result.append(unit)

	return result

func should_end_turn() -> bool:
	return units_awaiting_orders().is_empty()

## Hands the turn to the other team and refreshes the incoming side.
## A resolved battle is terminal, so this becomes a no-op once someone has won.
func end_turn() -> void:
	if is_over():
		return

	if phase == Phase.PLAYER_TURN:
		phase = Phase.ENEMY_TURN
	else:
		phase = Phase.PLAYER_TURN

	for unit in _grid.living_units_of_team(active_team()):
		unit.has_acted = false

## Called after every attack. Victory takes precedence over defeat in a mutual wipe.
func check_resolution() -> void:
	if is_over():
		return

	if _grid.living_units_of_team(UnitData.Team.ENEMY).is_empty():
		phase = Phase.VICTORY
		return

	if _grid.living_units_of_team(UnitData.Team.PLAYER).is_empty():
		phase = Phase.DEFEAT
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, all seven turn-order tests.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add turn phases with victory and defeat detection

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: Enemy AI

**Files:**
- Create: `core/ai_decision.gd`, `core/enemy_ai.gd`
- Create: `test/test_enemy_ai.gd`

**Interfaces:**
- Consumes: `Movement` (Task 4), `Combat.forecast` (Task 6), `BattleGrid` (Task 3)
- Produces:
  - `EnemyAI.KILL_BONUS` = `1000.0`
  - `EnemyAI.decide(grid: BattleGrid, unit: BattleUnit) -> AIDecision`
  - `EnemyAI.score(grid, attacker, defender) -> float`
  - `AIDecision.move_to: Vector2i`, `.target: BattleUnit` — `null` when the decision is to advance only

Per the plan's **Refinements** section: `KILL_BONUS` applies on non-crit `max_damage >= target.hp`. The AI weights kills it can guarantee, not ones it would need luck for. Ties break by lowest `y`, then lowest `x`, so behavior is reproducible.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

func _enemy_data(move_range: int, attack: int) -> UnitData:
	var data := UnitData.new()
	data.max_hp = 20
	data.attack = attack
	data.defense = 0
	data.accuracy = 1.0
	data.evasion = 0.0
	data.crit_rate = 0.0
	data.move_range = move_range
	data.attack_range = 1
	data.team = UnitData.Team.ENEMY

	return data

func _player_data(max_hp: int, defense: int) -> UnitData:
	var data := UnitData.new()
	data.max_hp = max_hp
	data.attack = 5
	data.defense = defense
	data.accuracy = 1.0
	data.evasion = 0.0
	data.crit_rate = 0.0
	data.move_range = 3
	data.attack_range = 1
	data.team = UnitData.Team.PLAYER

	return data

func _spawn(grid: BattleGrid, data: UnitData, cell: Vector2i) -> BattleUnit:
	var unit := BattleUnit.new(data, cell)
	grid.place_unit(unit, cell)

	return unit

func test_it_closes_and_attacks_an_adjacent_reachable_target() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray(["....."]))
	var enemy := _spawn(grid, _enemy_data(3, 8), Vector2i(0, 0))
	var player := _spawn(grid, _player_data(20, 0), Vector2i(3, 0))

	var decision := EnemyAI.decide(grid, enemy)

	assert_eq(decision.target, player, "it commits to the only target it can reach")
	assert_eq(decision.move_to, Vector2i(2, 0), "it stops adjacent, not on top of them")

func test_it_prefers_the_target_it_can_hurt_most() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".....",
		".....",
	]))
	var enemy := _spawn(grid, _enemy_data(4, 10), Vector2i(0, 0))
	var armored := _spawn(grid, _player_data(20, 8), Vector2i(2, 0))
	var soft := _spawn(grid, _player_data(20, 0), Vector2i(2, 1))

	var decision := EnemyAI.decide(grid, enemy)

	assert_eq(decision.target, soft, "10 damage beats 2")
	assert_ne(decision.target, armored)

func test_a_guaranteed_kill_outranks_raw_damage() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".....",
		".....",
	]))
	var enemy := _spawn(grid, _enemy_data(4, 10), Vector2i(0, 0))
	var healthy := _spawn(grid, _player_data(20, 0), Vector2i(2, 0))
	var wounded := _spawn(grid, _player_data(20, 6), Vector2i(2, 1))
	wounded.hp = 3

	var decision := EnemyAI.decide(grid, enemy)

	assert_eq(decision.target, wounded, "a certain kill for 4 beats a scratch for 10")
	assert_ne(decision.target, healthy)

func test_it_advances_when_nothing_is_in_reach() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray(["........"]))
	var enemy := _spawn(grid, _enemy_data(2, 8), Vector2i(0, 0))
	_spawn(grid, _player_data(20, 0), Vector2i(7, 0))

	var decision := EnemyAI.decide(grid, enemy)

	assert_null(decision.target, "nothing is attackable this turn")
	assert_eq(decision.move_to, Vector2i(2, 0), "it spends its full budget closing the distance")

func test_it_routes_around_walls_when_advancing() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".#..",
		"....",
	]))
	var enemy := _spawn(grid, _enemy_data(2, 8), Vector2i(0, 0))
	_spawn(grid, _player_data(20, 0), Vector2i(3, 0))

	var decision := EnemyAI.decide(grid, enemy)

	assert_null(decision.target)
	assert_eq(decision.move_to, Vector2i(1, 1), "down and across, since the wall blocks the direct line")

func test_it_holds_position_when_it_cannot_close_at_all() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		".#.",
	]))
	var enemy := _spawn(grid, _enemy_data(3, 8), Vector2i(0, 0))
	_spawn(grid, _player_data(20, 0), Vector2i(2, 0))

	var decision := EnemyAI.decide(grid, enemy)

	assert_null(decision.target)
	assert_eq(decision.move_to, Vector2i(0, 0), "walled off entirely, so it stays put")

func test_ties_break_deterministically() -> void:
	var grid := BattleGrid.from_ascii(PackedStringArray([
		"...",
		"...",
		"...",
	]))
	var enemy := _spawn(grid, _enemy_data(3, 8), Vector2i(1, 1))
	_spawn(grid, _player_data(20, 0), Vector2i(1, 0))
	_spawn(grid, _player_data(20, 0), Vector2i(1, 2))

	var first := EnemyAI.decide(grid, enemy)
	var second := EnemyAI.decide(grid, enemy)

	assert_eq(first.move_to, second.move_to, "the same board yields the same decision")
	assert_eq(first.target, second.target)
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL — `EnemyAI` is not a known identifier.

- [ ] **Step 3: Implement `core/ai_decision.gd`**

```gdscript
class_name AIDecision
extends RefCounted

## Where the unit should stand when it is done moving.
var move_to: Vector2i = Vector2i.ZERO

## Who to attack from move_to, or null to advance without attacking.
var target: BattleUnit = null
```

- [ ] **Step 4: Implement `core/enemy_ai.gd`**

```gdscript
class_name EnemyAI
extends RefCounted

## Large enough that any guaranteed kill outranks any amount of chip damage.
const KILL_BONUS := 1000.0

## Chooses where one enemy unit should stand and who it should hit.
## Scoring is fully deterministic; the only randomness in a turn is in the attacks that follow.
static func decide(grid: BattleGrid, unit: BattleUnit) -> AIDecision:
	var decision := AIDecision.new()
	decision.move_to = unit.cell

	var field := Movement.field(grid, unit)
	var targets := grid.living_units_of_team(UnitData.Team.PLAYER)
	var best_score := -1.0

	for cell in _sorted(field.reachable_cells()):
		for target in targets:
			if Movement.manhattan(cell, target.cell) > unit.data.attack_range:
				continue

			var candidate := score(grid, unit, target)
			if candidate > best_score:
				best_score = candidate
				decision.move_to = cell
				decision.target = target

	if decision.target != null:
		return decision

	decision.move_to = _advance_toward_nearest(grid, unit, field, targets)

	return decision

## Expected damage from one attack, plus a bonus for a kill that needs no luck.
static func score(grid: BattleGrid, attacker: BattleUnit, defender: BattleUnit) -> float:
	var prediction := Combat.forecast(grid, attacker, defender)
	var average := (prediction.min_damage + prediction.max_damage) / 2.0
	var expected := prediction.hit_chance * average * (1.0 + prediction.crit_chance * (Combat.CRIT_MULTIPLIER - 1))

	if prediction.max_damage >= defender.hp:
		expected += KILL_BONUS

	return expected

## Walks as far along the cheapest route to the nearest target as the budget allows.
## Returns the unit's own cell when no route exists at all.
static func _advance_toward_nearest(grid: BattleGrid, unit: BattleUnit, field: MovementField, targets: Array[BattleUnit]) -> Vector2i:
	var approach := AStarGrid2D.new()
	approach.region = Rect2i(Vector2i.ZERO, grid.size)
	approach.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	approach.update()

	for y in grid.size.y:
		for x in grid.size.x:
			var cell := Vector2i(x, y)
			var blocker := grid.unit_at(cell)
			var blocked := not Terrain.is_passable(grid.terrain_at(cell))
			if blocker != null and blocker != unit and blocker.team() != unit.team():
				blocked = true

			approach.set_point_solid(cell, blocked)

	var best_cell := unit.cell
	var best_distance := -1

	for target in _sorted_units(targets):
		## The target's own cell was marked solid along with every other opposing unit,
		## and A* cannot path onto a solid cell — so clear the destination for its own search.
		approach.set_point_solid(target.cell, false)
		var route := approach.get_id_path(unit.cell, target.cell)
		approach.set_point_solid(target.cell, true)

		if route.size() < 2:
			continue

		for index in range(route.size() - 1, 0, -1):
			var step: Vector2i = route[index]
			if not field.can_reach(step):
				continue

			var remaining := Movement.manhattan(step, target.cell)
			if best_distance < 0 or remaining < best_distance:
				best_distance = remaining
				best_cell = step

			break

	return best_cell

## Row-major order, so ties resolve the same way on every run.
static func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result := cells.duplicate()
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y

		return a.x < b.x
	)

	return result

static func _sorted_units(units: Array[BattleUnit]) -> Array[BattleUnit]:
	var result := units.duplicate()
	result.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.cell.y != b.cell.y:
			return a.cell.y < b.cell.y

		return a.cell.x < b.cell.x
	)

	return result
```

- [ ] **Step 5: Run tests to verify they pass**

Expected: PASS, all seven AI tests.

- [ ] **Step 6: Run the whole suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: every test across all eight files passes. **The entire rules engine is now complete and verified without a single Node.**

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add expected-value enemy AI with deterministic tie-breaking

Kills that need no luck outrank chip damage. Ties break row-major so
the same board always produces the same decision.

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 11: Grid rendering and cursor

Presentation begins here. **No `.tscn` files are hand-authored beyond one nearly-empty root** — every child node is built in code. Scene files are opaque to review and merge badly; code is neither.

Placeholder art means `draw_rect`, not sprites or a `TileSet`. That skips authoring `.tres` resources entirely.

**Files:**
- Create: `scenes/grid_geometry.gd`, `scenes/grid_view.gd`, `scenes/cursor.gd`
- Create: `scenes/battle.tscn`, `scenes/battle.gd` (skeleton only)
- Create: `test/test_grid_geometry.gd`
- Modify: `project.godot` (add `run/main_scene` and input actions)

**Interfaces:**
- Consumes: `BattleGrid`, `Terrain` (Tasks 2-3)
- Produces:
  - `GridGeometry.CELL_SIZE` = `48`
  - `GridGeometry.cell_to_position(cell: Vector2i) -> Vector2`
  - `GridGeometry.cell_center(cell: Vector2i) -> Vector2`
  - `GridGeometry.position_to_cell(position: Vector2) -> Vector2i`
  - `GridView.grid`, `.move_cells`, `.attack_cells`, `.refresh()`
  - `Cursor.cell`, signals `moved(cell)`, `confirmed(cell)`, `canceled`

- [ ] **Step 1: Write the failing geometry test**

```gdscript
extends GutTest

func test_a_cell_maps_to_its_top_left_corner() -> void:
	assert_eq(GridGeometry.cell_to_position(Vector2i(0, 0)), Vector2(0, 0))
	assert_eq(GridGeometry.cell_to_position(Vector2i(2, 3)), Vector2(96, 144))

func test_cell_center_is_half_a_cell_in() -> void:
	assert_eq(GridGeometry.cell_center(Vector2i(0, 0)), Vector2(24, 24))
	assert_eq(GridGeometry.cell_center(Vector2i(1, 1)), Vector2(72, 72))

func test_a_position_maps_back_to_its_cell() -> void:
	assert_eq(GridGeometry.position_to_cell(Vector2(0, 0)), Vector2i(0, 0))
	assert_eq(GridGeometry.position_to_cell(Vector2(47, 47)), Vector2i(0, 0), "still inside the first cell")
	assert_eq(GridGeometry.position_to_cell(Vector2(48, 0)), Vector2i(1, 0))

func test_negative_positions_floor_rather_than_truncate() -> void:
	assert_eq(GridGeometry.position_to_cell(Vector2(-1, -1)), Vector2i(-1, -1), "truncation would wrongly give (0, 0)")

func test_the_round_trip_is_stable() -> void:
	for x in 5:
		for y in 5:
			var cell := Vector2i(x, y)
			assert_eq(GridGeometry.position_to_cell(GridGeometry.cell_center(cell)), cell)
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL — `GridGeometry` is not a known identifier.

- [ ] **Step 3: Implement `scenes/grid_geometry.gd`**

```gdscript
class_name GridGeometry
extends RefCounted

const CELL_SIZE := 48

static func cell_to_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE)

static func cell_center(cell: Vector2i) -> Vector2:
	return cell_to_position(cell) + Vector2(CELL_SIZE, CELL_SIZE) * 0.5

## floori rather than a cast, so cells left of and above the origin map correctly.
static func position_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))
```

- [ ] **Step 4: Run the geometry test to verify it passes**

Expected: PASS, all five tests.

- [ ] **Step 5: Implement `scenes/grid_view.gd`**

```gdscript
class_name GridView
extends Node2D

const TERRAIN_COLORS := {
	Terrain.Type.PLAIN: Color("4a7a4a"),
	Terrain.Type.FOREST: Color("1f4a24"),
	Terrain.Type.WALL: Color("2b2b33"),
}

const GRID_LINE := Color(0.0, 0.0, 0.0, 0.25)
const MOVE_HIGHLIGHT := Color(0.30, 0.60, 1.0, 0.45)
const ATTACK_HIGHLIGHT := Color(1.0, 0.30, 0.30, 0.45)

var grid: BattleGrid = null
var move_cells: Array[Vector2i] = []
var attack_cells: Array[Vector2i] = []

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	if grid == null:
		return

	for y in grid.size.y:
		for x in grid.size.x:
			var cell := Vector2i(x, y)
			var rect := Rect2(GridGeometry.cell_to_position(cell), Vector2.ONE * GridGeometry.CELL_SIZE)
			draw_rect(rect, TERRAIN_COLORS[grid.terrain_at(cell)])
			draw_rect(rect, GRID_LINE, false, 1.0)

	_draw_highlights(move_cells, MOVE_HIGHLIGHT)
	_draw_highlights(attack_cells, ATTACK_HIGHLIGHT)

func _draw_highlights(cells: Array[Vector2i], color: Color) -> void:
	for cell in cells:
		draw_rect(Rect2(GridGeometry.cell_to_position(cell), Vector2.ONE * GridGeometry.CELL_SIZE), color)
```

- [ ] **Step 6: Implement `scenes/cursor.gd`**

```gdscript
class_name Cursor
extends Node2D

signal moved(cell: Vector2i)
signal confirmed(cell: Vector2i)
signal canceled

const OUTLINE := Color("ffd75e")

var cell: Vector2i = Vector2i.ZERO
var bounds: Vector2i = Vector2i.ONE
var active: bool = true

func _process(_delta: float) -> void:
	position = GridGeometry.cell_to_position(cell)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE * GridGeometry.CELL_SIZE), OUTLINE, false, 3.0)

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if event is InputEventMouseMotion:
		_move_to(GridGeometry.position_to_cell(get_global_mouse_position()))
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		confirmed.emit(cell)
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		canceled.emit()
		return

	for action in _DIRECTIONS:
		if event.is_action_pressed(action):
			_move_to(cell + _DIRECTIONS[action])
			return

const _DIRECTIONS := {
	"ui_up": Vector2i(0, -1),
	"ui_down": Vector2i(0, 1),
	"ui_left": Vector2i(-1, 0),
	"ui_right": Vector2i(1, 0),
}

func _move_to(target: Vector2i) -> void:
	var clamped := Vector2i(clampi(target.x, 0, bounds.x - 1), clampi(target.y, 0, bounds.y - 1))
	if clamped == cell:
		return

	cell = clamped
	moved.emit(cell)
```

- [ ] **Step 7: Create `scenes/battle.tscn` and a skeleton `scenes/battle.gd`**

The scene file stays this small permanently. Everything else is built in `_ready()`.

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/battle.gd" id="1"]

[node name="Battle" type="Node2D"]
script = ExtResource("1")
```

```gdscript
extends Node2D

const MARGIN := Vector2(40, 40)

var _grid: BattleGrid
var _grid_view: GridView
var _cursor: Cursor

func _ready() -> void:
	_grid = BattleGrid.from_ascii(PackedStringArray([
		"..F....F..",
		"..........",
		".#......#.",
		"..........",
	]))

	_grid_view = GridView.new()
	_grid_view.grid = _grid
	_grid_view.position = MARGIN
	add_child(_grid_view)

	_cursor = Cursor.new()
	_cursor.bounds = _grid.size
	_cursor.position = MARGIN
	_grid_view.add_child(_cursor)

	_cursor.moved.connect(_on_cursor_moved)
	_grid_view.refresh()

## Temporary until Task 14: proves input reaches the cursor and redraws land.
func _on_cursor_moved(cell: Vector2i) -> void:
	_grid_view.move_cells = [cell] as Array[Vector2i]
	_grid_view.refresh()
	_cursor.queue_redraw()
```

- [ ] **Step 8: Point `project.godot` at the scene**

Add to the `[application]` section:

```ini
run/main_scene="res://scenes/battle.tscn"
```

The `ui_*` actions used by the cursor are Godot built-ins — arrows, Enter, and Escape work with no input map configuration.

- [ ] **Step 9: Run the game and verify by eye**

Run: `godot`
Expected: a 10x4 grid with visible plain, forest, and wall colors. Arrow keys and mouse move a yellow cursor outline; it clamps at the edges and highlights the hovered cell in blue.

**This is a manual check — actually look at it.** If the window is black, the scene is not wired; if the cursor does not move, input is not reaching `_unhandled_input`.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: draw the battle grid and add a keyboard and mouse cursor

Scene children are built in code; battle.tscn stays a bare Node2D so
nothing important lives in an unreviewable scene file.

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 12: Unit views and movement animation

**Files:**
- Create: `scenes/unit_view.gd`
- Modify: `scenes/battle.gd`

**Interfaces:**
- Consumes: `BattleUnit` (Task 2), `GridGeometry` (Task 11)
- Produces:
  - `UnitView.setup(unit: BattleUnit) -> void`
  - `UnitView.walk_path(path: Array[Vector2i]) -> void`, signal `walk_finished`
  - `UnitView.refresh() -> void`
  - `UnitView.snap() -> void`

- [ ] **Step 1: Implement `scenes/unit_view.gd`**

```gdscript
class_name UnitView
extends Node2D

signal walk_finished

const STEP_SECONDS := 0.12
const BODY_INSET := 8.0
const HP_BAR_HEIGHT := 5.0
const SPENT_MODULATE := Color(0.55, 0.55, 0.55, 1.0)

var unit: BattleUnit = null

func setup(battle_unit: BattleUnit) -> void:
	unit = battle_unit
	snap()

## Places the view at the unit's cell with no animation.
func snap() -> void:
	position = GridGeometry.cell_to_position(unit.cell)
	refresh()

func refresh() -> void:
	if unit == null:
		return

	modulate = Color.WHITE
	if unit.has_acted:
		modulate = SPENT_MODULATE

	visible = unit.is_alive()
	queue_redraw()

## Slides the view one cell at a time along the path, then reports completion.
## An empty path still emits, so callers never have to special-case standing still.
func walk_path(path: Array[Vector2i]) -> void:
	if path.is_empty():
		walk_finished.emit()
		return

	var tween := create_tween()
	for cell in path:
		tween.tween_property(self, "position", GridGeometry.cell_to_position(cell), STEP_SECONDS)

	tween.finished.connect(func() -> void:
		walk_finished.emit()
	)

func _draw() -> void:
	if unit == null:
		return

	var size := GridGeometry.CELL_SIZE - BODY_INSET * 2.0
	draw_rect(Rect2(Vector2.ONE * BODY_INSET, Vector2.ONE * size), unit.data.color)

	var ratio := clampf(float(unit.hp) / float(unit.data.max_hp), 0.0, 1.0)
	var bar_top := Vector2(BODY_INSET, GridGeometry.CELL_SIZE - BODY_INSET - HP_BAR_HEIGHT)
	draw_rect(Rect2(bar_top, Vector2(size, HP_BAR_HEIGHT)), Color(0.1, 0.05, 0.05))
	draw_rect(Rect2(bar_top, Vector2(size * ratio, HP_BAR_HEIGHT)), Color(0.35, 0.85, 0.35))
```

- [ ] **Step 2: Spawn views from `scenes/battle.gd`**

Replace `_ready()`'s temporary body. Two units are hardcoded here purely to exercise the animation; Task 15 replaces this with the real scenario.

```gdscript
var _views: Dictionary[BattleUnit, UnitView] = {}

func _spawn(data: UnitData, cell: Vector2i) -> BattleUnit:
	var unit := BattleUnit.new(data, cell)
	_grid.place_unit(unit, cell)

	var view := UnitView.new()
	view.setup(unit)
	_grid_view.add_child(view)
	_views[unit] = view

	return unit
```

- [ ] **Step 3: Add a temporary walk trigger to prove the animation**

Wire the cursor's `confirmed` signal to walk the first unit to the clicked cell along a real computed path. This is scaffolding — Task 14 replaces it.

```gdscript
func _on_cursor_confirmed(cell: Vector2i) -> void:
	var unit: BattleUnit = _views.keys()[0]
	var field := Movement.field(_grid, unit)
	if not field.can_reach(cell):
		return

	var path := field.path_to(cell)
	_grid.move_unit(unit, cell)
	_views[unit].walk_path(path)
```

- [ ] **Step 4: Run the game and verify by eye**

Run: `godot`
Expected: two colored squares with green HP bars sit on the grid. Clicking a reachable cell slides the first unit there one tile at a time, routing around walls rather than through them.

- [ ] **Step 5: Run the full test suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: PASS. Presentation work must not have broken any rule.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: render units with HP bars and tween them along movement paths

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 13: Action menu and forecast panel

The formatting is pure and therefore tested; the widgets that display it are not.

**Files:**
- Create: `ui/forecast_format.gd`, `ui/action_menu.gd`, `ui/forecast_panel.gd`
- Create: `test/test_forecast_format.gd`

**Interfaces:**
- Consumes: `AttackForecast` (Task 6)
- Produces:
  - `ForecastFormat.percent(value: float) -> String`
  - `ForecastFormat.damage(forecast: AttackForecast) -> String`
  - `ForecastFormat.line(forecast: AttackForecast) -> String`
  - `ActionMenu.open(at: Vector2, can_attack: bool)`, `.close()`, signals `attack_chosen`, `wait_chosen`
  - `ForecastPanel.show_forecast(forecast: AttackForecast)`, `.clear()`

- [ ] **Step 1: Write the failing format test**

```gdscript
extends GutTest

func _forecast(hit: float, crit: float, low: int, high: int) -> AttackForecast:
	var forecast := AttackForecast.new()
	forecast.hit_chance = hit
	forecast.crit_chance = crit
	forecast.min_damage = low
	forecast.max_damage = high
	forecast.crit_damage = high * Combat.CRIT_MULTIPLIER

	return forecast

func test_percentages_round_to_whole_numbers() -> void:
	assert_eq(ForecastFormat.percent(0.85), "85%")
	assert_eq(ForecastFormat.percent(1.0), "100%")
	assert_eq(ForecastFormat.percent(0.0), "0%")
	assert_eq(ForecastFormat.percent(0.855), "86%", "rounds rather than truncates")

func test_a_damage_range_shows_both_ends() -> void:
	assert_eq(ForecastFormat.damage(_forecast(0.8, 0.2, 6, 8)), "6-8")

func test_a_single_damage_value_does_not_repeat_itself() -> void:
	assert_eq(ForecastFormat.damage(_forecast(0.8, 0.2, 1, 1)), "1", "not '1-1'")

func test_the_full_line_reads_as_the_spec_describes() -> void:
	assert_eq(ForecastFormat.line(_forecast(0.85, 0.21, 6, 8)), "Deals 6-8   Hit 85%   Crit 21%")

func test_a_guaranteed_hit_reads_as_one_hundred_percent() -> void:
	assert_eq(ForecastFormat.line(_forecast(1.0, 0.0, 9, 9)), "Deals 9   Hit 100%   Crit 0%")
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL — `ForecastFormat` is not a known identifier.

- [ ] **Step 3: Implement `ui/forecast_format.gd`**

```gdscript
class_name ForecastFormat
extends RefCounted

## Floats are stored in [0.0, 1.0] everywhere in core.
## They become percentages here, at the UI edge, and nowhere else.
static func percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)

static func damage(forecast: AttackForecast) -> String:
	if forecast.min_damage == forecast.max_damage:
		return str(forecast.min_damage)

	return "%d-%d" % [forecast.min_damage, forecast.max_damage]

static func line(forecast: AttackForecast) -> String:
	return "Deals %s   Hit %s   Crit %s" % [damage(forecast), percent(forecast.hit_chance), percent(forecast.crit_chance)]
```

- [ ] **Step 4: Run the format test to verify it passes**

Expected: PASS, all five tests.

- [ ] **Step 5: Implement `ui/action_menu.gd`**

```gdscript
class_name ActionMenu
extends VBoxContainer

signal attack_chosen
signal wait_chosen

var _attack_button: Button
var _wait_button: Button

func _ready() -> void:
	_attack_button = Button.new()
	_attack_button.text = "Attack"
	_attack_button.pressed.connect(func() -> void: attack_chosen.emit())
	add_child(_attack_button)

	_wait_button = Button.new()
	_wait_button.text = "Wait"
	_wait_button.pressed.connect(func() -> void: wait_chosen.emit())
	add_child(_wait_button)

	hide()

## Attack is disabled rather than hidden, so the menu never changes shape under the player's cursor.
func open(at: Vector2, can_attack: bool) -> void:
	position = at
	_attack_button.disabled = not can_attack
	show()

	if can_attack:
		_attack_button.grab_focus()
	else:
		_wait_button.grab_focus()

func close() -> void:
	hide()
```

- [ ] **Step 6: Implement `ui/forecast_panel.gd`**

```gdscript
class_name ForecastPanel
extends PanelContainer

var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	add_child(_label)
	hide()

func show_forecast(forecast: AttackForecast) -> void:
	_label.text = ForecastFormat.line(forecast)
	show()

func clear() -> void:
	hide()
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add action menu and forecast panel with tested formatting

Percentages are produced at the UI edge only; core stores floats.

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 14: Wire the full loop

The bridge. This is the one script allowed to know about both layers, and its job is to be a state machine that translates input into core calls and core answers into view calls.

**Files:**
- Create: `ui/result_screen.gd`
- Rewrite: `scenes/battle.gd`

**Interfaces:**
- Consumes: everything from Tasks 2-13
- Produces: a playable battle

**View states:** `SELECTING_UNIT` → `CHOOSING_MOVE` → `CHOOSING_ACTION` → `CHOOSING_TARGET` → `ANIMATING` → back to `SELECTING_UNIT`; plus `ENEMY_TURN` and `RESOLVED`.

- [ ] **Step 1: Implement `ui/result_screen.gd`**

```gdscript
class_name ResultScreen
extends CenterContainer

signal restart_requested

var _label: Label

func _ready() -> void:
	var box := VBoxContainer.new()
	add_child(box)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 48)
	box.add_child(_label)

	var button := Button.new()
	button.text = "Again"
	button.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(button)

	hide()

func show_result(victory: bool) -> void:
	if victory:
		_label.text = "Victory"
	else:
		_label.text = "Defeat"

	show()
```

- [ ] **Step 2: Rewrite `scenes/battle.gd`**

```gdscript
extends Node2D

enum State { SELECTING_UNIT, CHOOSING_MOVE, CHOOSING_ACTION, CHOOSING_TARGET, ANIMATING, ENEMY_TURN, RESOLVED }

const MARGIN := Vector2(40, 40)
const ENEMY_STEP_DELAY := 0.35

var _grid: BattleGrid
var _turns: TurnOrder
var _rolls: RealRollSource
var _state: State = State.SELECTING_UNIT

var _grid_view: GridView
var _cursor: Cursor
var _action_menu: ActionMenu
var _forecast_panel: ForecastPanel
var _result_screen: ResultScreen
var _views: Dictionary[BattleUnit, UnitView] = {}

var _selected: BattleUnit = null
var _field: MovementField = null
var _origin_cell: Vector2i = Vector2i.ZERO

func _ready() -> void:
	_start_battle()

func _start_battle() -> void:
	var seed_value := int(Time.get_unix_time_from_system())
	_rolls = RealRollSource.new(seed_value)
	print("Sortie battle seed: %d" % seed_value)

	_grid = Scenario.build_grid()
	_turns = TurnOrder.new(_grid)
	_build_views()
	_enter_unit_selection()

func _build_views() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	_views.clear()

	_grid_view = GridView.new()
	_grid_view.grid = _grid
	_grid_view.position = MARGIN
	add_child(_grid_view)

	for unit in Scenario.populate(_grid):
		var view := UnitView.new()
		view.setup(unit)
		_grid_view.add_child(view)
		_views[unit] = view

	_cursor = Cursor.new()
	_cursor.bounds = _grid.size
	_grid_view.add_child(_cursor)
	_cursor.moved.connect(_on_cursor_moved)
	_cursor.confirmed.connect(_on_cursor_confirmed)
	_cursor.canceled.connect(_on_cancel)

	var layer := CanvasLayer.new()
	add_child(layer)

	_action_menu = ActionMenu.new()
	layer.add_child(_action_menu)
	_action_menu.attack_chosen.connect(_on_attack_chosen)
	_action_menu.wait_chosen.connect(_on_wait_chosen)

	_forecast_panel = ForecastPanel.new()
	_forecast_panel.position = Vector2(40, 8)
	layer.add_child(_forecast_panel)

	_result_screen = ResultScreen.new()
	_result_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_result_screen)
	_result_screen.restart_requested.connect(_start_battle)

	_refresh_all()

func _refresh_all() -> void:
	for view in _views.values():
		view.refresh()

	_grid_view.refresh()

## --- Player turn ---

func _enter_unit_selection() -> void:
	_state = State.SELECTING_UNIT
	_selected = null
	_field = null
	_grid_view.move_cells.clear()
	_grid_view.attack_cells.clear()
	_forecast_panel.clear()
	_action_menu.close()
	_cursor.active = true
	_refresh_all()

	if _turns.should_end_turn():
		_end_player_turn()

func _on_cursor_moved(cell: Vector2i) -> void:
	if _state != State.CHOOSING_TARGET:
		return

	var target := _grid.unit_at(cell)
	if target == null or target.team() == UnitData.Team.PLAYER or not target.is_alive():
		_forecast_panel.clear()
		return

	_forecast_panel.show_forecast(Combat.forecast(_grid, _selected, target))

func _on_cursor_confirmed(cell: Vector2i) -> void:
	match _state:
		State.SELECTING_UNIT:
			_try_select(cell)
		State.CHOOSING_MOVE:
			_try_move(cell)
		State.CHOOSING_TARGET:
			_try_attack(cell)

func _try_select(cell: Vector2i) -> void:
	var unit := _grid.unit_at(cell)
	if unit == null or unit.team() != UnitData.Team.PLAYER or unit.has_acted or not unit.is_alive():
		return

	_selected = unit
	_origin_cell = unit.cell
	_field = Movement.field(_grid, unit)
	_grid_view.move_cells = _field.reachable_cells()
	_grid_view.refresh()
	_state = State.CHOOSING_MOVE

func _try_move(cell: Vector2i) -> void:
	if not _field.can_reach(cell):
		return

	var path := _field.path_to(cell)
	_grid.move_unit(_selected, cell)
	_grid_view.move_cells.clear()
	_grid_view.refresh()
	_state = State.ANIMATING
	_cursor.active = false

	var view: UnitView = _views[_selected]
	view.walk_finished.connect(_on_move_finished, CONNECT_ONE_SHOT)
	view.walk_path(path)

func _on_move_finished() -> void:
	_state = State.CHOOSING_ACTION
	_action_menu.open(GridGeometry.cell_center(_selected.cell) + MARGIN, not _targets_in_range().is_empty())

func _targets_in_range() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for cell in Movement.attackable_cells(_grid, _selected.cell, _selected.data.attack_range):
		var occupant := _grid.unit_at(cell)
		if occupant != null and occupant.is_alive() and occupant.team() == UnitData.Team.ENEMY:
			result.append(occupant)

	return result

func _on_attack_chosen() -> void:
	_action_menu.close()
	_state = State.CHOOSING_TARGET
	_cursor.active = true

	var cells: Array[Vector2i] = []
	for target in _targets_in_range():
		cells.append(target.cell)

	_grid_view.attack_cells = cells
	_grid_view.refresh()

func _on_wait_chosen() -> void:
	_action_menu.close()
	_selected.has_acted = true
	_enter_unit_selection()

func _try_attack(cell: Vector2i) -> void:
	var target := _grid.unit_at(cell)
	if target == null or target.team() != UnitData.Team.ENEMY or not target.is_alive():
		return

	if Movement.manhattan(_selected.cell, cell) > _selected.data.attack_range:
		return

	Combat.exchange(_grid, _selected, target, _rolls)
	_selected.has_acted = true
	_cleanup_dead()
	_turns.check_resolution()
	_refresh_all()

	if _finish_if_resolved():
		return

	_enter_unit_selection()

## Cancel backs out one step rather than abandoning the whole action.
func _on_cancel() -> void:
	match _state:
		State.CHOOSING_MOVE:
			_enter_unit_selection()
		State.CHOOSING_TARGET:
			_grid_view.attack_cells.clear()
			_forecast_panel.clear()
			_grid_view.refresh()
			_on_move_finished()

func _cleanup_dead() -> void:
	for unit in _views.keys():
		if not unit.is_alive():
			_grid.remove_unit(unit)

func _finish_if_resolved() -> bool:
	if not _turns.is_over():
		return false

	_state = State.RESOLVED
	_cursor.active = false
	_result_screen.show_result(_turns.phase == TurnOrder.Phase.VICTORY)

	return true

## --- Enemy turn ---

func _end_player_turn() -> void:
	_turns.end_turn()
	_state = State.ENEMY_TURN
	_cursor.active = false
	_run_enemy_turn()

func _run_enemy_turn() -> void:
	for unit in _turns.units_awaiting_orders():
		if not unit.is_alive():
			continue

		await _take_enemy_action(unit)

		if _turns.is_over():
			_finish_if_resolved()
			return

	_turns.end_turn()
	_enter_unit_selection()

func _take_enemy_action(unit: BattleUnit) -> void:
	var decision := EnemyAI.decide(_grid, unit)
	var field := Movement.field(_grid, unit)
	var path := field.path_to(decision.move_to)

	if decision.move_to != unit.cell:
		_grid.move_unit(unit, decision.move_to)
		var view: UnitView = _views[unit]
		view.walk_path(path)
		await view.walk_finished

	if decision.target != null:
		Combat.exchange(_grid, unit, decision.target, _rolls)
		_cleanup_dead()
		_turns.check_resolution()

	unit.has_acted = true
	_refresh_all()

	await get_tree().create_timer(ENEMY_STEP_DELAY).timeout
```

- [ ] **Step 3: Run the full test suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: PASS. `Scenario` does not exist yet, so this task cannot run the game — Task 15 supplies it.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: wire the full battle loop through a view state machine

battle.gd is the only script touching both layers: it translates input
into core calls and core answers into view calls.

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 15: The scenario, and playing it

The last task supplies the actual battle and confirms the whole thing is a game.

**Files:**
- Create: `core/scenario.gd`
- Create: `test/test_scenario.gd`
- Modify: `docs/superpowers/specs/2026-08-30-sortie-design.md` (mark implemented)

**Interfaces:**
- Consumes: everything
- Produces:
  - `Scenario.build_grid() -> BattleGrid`
  - `Scenario.populate(grid: BattleGrid) -> Array[BattleUnit]`

**The roster.** The Archer's reach of 2 is the tactical hook: it can strike a reach-1 enemy without being countered, but it is fragile enough that being caught costs dearly.

| Unit | Team | HP | Atk | Def | Acc | Eva | Crit | Move | Range | Cell |
|---|---|---|---|---|---|---|---|---|---|---|
| Vanguard | Player | 24 | 9 | 4 | 0.90 | 0.05 | 0.05 | 3 | 1 | (0, 7) |
| Archer | Player | 16 | 8 | 1 | 0.85 | 0.10 | 0.15 | 3 | 2 | (1, 7) |
| Skirmisher | Player | 18 | 7 | 2 | 0.95 | 0.20 | 0.25 | 5 | 1 | (0, 6) |
| Brute | Enemy | 26 | 10 | 3 | 0.85 | 0.00 | 0.05 | 3 | 1 | (9, 0) |
| Raider | Enemy | 18 | 8 | 1 | 0.90 | 0.10 | 0.15 | 4 | 1 | (8, 0) |
| Scout | Enemy | 14 | 6 | 0 | 0.90 | 0.25 | 0.10 | 5 | 1 | (9, 1) |

- [ ] **Step 1: Write the failing scenario test**

A scenario is data, and data can be wrong in ways that only show up mid-battle. These assertions catch that at test time.

```gdscript
extends GutTest

func test_the_map_is_the_expected_shape() -> void:
	var grid := Scenario.build_grid()

	assert_eq(grid.size, Vector2i(10, 8))

func test_both_teams_are_present() -> void:
	var grid := Scenario.build_grid()
	Scenario.populate(grid)

	assert_eq(grid.living_units_of_team(UnitData.Team.PLAYER).size(), 3)
	assert_eq(grid.living_units_of_team(UnitData.Team.ENEMY).size(), 3)

func test_every_unit_starts_in_bounds_on_passable_ground() -> void:
	var grid := Scenario.build_grid()

	for unit in Scenario.populate(grid):
		assert_true(grid.is_in_bounds(unit.cell), "%s starts out of bounds at %s" % [unit.data.unit_name, unit.cell])
		assert_true(Terrain.is_passable(grid.terrain_at(unit.cell)), "%s starts inside a wall" % unit.data.unit_name)

func test_no_two_units_share_a_cell() -> void:
	var grid := Scenario.build_grid()
	var seen: Dictionary[Vector2i, bool] = {}

	for unit in Scenario.populate(grid):
		assert_false(seen.has(unit.cell), "two units start on %s" % unit.cell)
		seen[unit.cell] = true

func test_the_battle_does_not_open_already_resolved() -> void:
	var grid := Scenario.build_grid()
	Scenario.populate(grid)
	var turns := TurnOrder.new(grid)
	turns.check_resolution()

	assert_false(turns.is_over(), "someone would have to be wiped out before the first move")

func test_the_teams_do_not_start_within_reach_of_each_other() -> void:
	var grid := Scenario.build_grid()
	Scenario.populate(grid)

	for player in grid.living_units_of_team(UnitData.Team.PLAYER):
		for enemy in grid.living_units_of_team(UnitData.Team.ENEMY):
			var reach: int = maxi(player.data.attack_range, enemy.data.attack_range)
			assert_true(Movement.manhattan(player.cell, enemy.cell) > reach, "the armies start already in contact")
```

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL — `Scenario` is not a known identifier.

- [ ] **Step 3: Implement `core/scenario.gd`**

```gdscript
class_name Scenario
extends RefCounted

const MAP := [
	"..F....F..",
	"..........",
	".#......#.",
	"..........",
	"..........",
	".#......#.",
	"..........",
	"..F....F..",
]

static func build_grid() -> BattleGrid:
	return BattleGrid.from_ascii(PackedStringArray(MAP))

## Places both armies and returns them in spawn order.
static func populate(grid: BattleGrid) -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []

	units.append(_spawn(grid, Vector2i(0, 7), _make("Vanguard", 24, 9, 4, 0.90, 0.05, 0.05, 3, 1, UnitData.Team.PLAYER, Color("4d7fd4"))))
	units.append(_spawn(grid, Vector2i(1, 7), _make("Archer", 16, 8, 1, 0.85, 0.10, 0.15, 3, 2, UnitData.Team.PLAYER, Color("6fb3e0"))))
	units.append(_spawn(grid, Vector2i(0, 6), _make("Skirmisher", 18, 7, 2, 0.95, 0.20, 0.25, 5, 1, UnitData.Team.PLAYER, Color("9ad4f0"))))

	units.append(_spawn(grid, Vector2i(9, 0), _make("Brute", 26, 10, 3, 0.85, 0.00, 0.05, 3, 1, UnitData.Team.ENEMY, Color("c1443f"))))
	units.append(_spawn(grid, Vector2i(8, 0), _make("Raider", 18, 8, 1, 0.90, 0.10, 0.15, 4, 1, UnitData.Team.ENEMY, Color("d97148"))))
	units.append(_spawn(grid, Vector2i(9, 1), _make("Scout", 14, 6, 0, 0.90, 0.25, 0.10, 5, 1, UnitData.Team.ENEMY, Color("e0a05a"))))

	return units

static func _spawn(grid: BattleGrid, cell: Vector2i, data: UnitData) -> BattleUnit:
	var unit := BattleUnit.new(data, cell)
	grid.place_unit(unit, cell)

	return unit

static func _make(
	unit_name: String,
	max_hp: int,
	attack: int,
	defense: int,
	accuracy: float,
	evasion: float,
	crit_rate: float,
	move_range: int,
	attack_range: int,
	team: UnitData.Team,
	color: Color
) -> UnitData:
	var data := UnitData.new()
	data.unit_name = unit_name
	data.max_hp = max_hp
	data.attack = attack
	data.defense = defense
	data.accuracy = accuracy
	data.evasion = evasion
	data.crit_rate = crit_rate
	data.move_range = move_range
	data.attack_range = attack_range
	data.team = team
	data.color = color

	return data
```

- [ ] **Step 4: Run the whole suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: PASS across all eleven test files.

- [ ] **Step 5: Play it to victory**

Run: `godot`

Walk through the whole loop and confirm each of these by eye:
1. Three blue units bottom-left, three red top-right, forest and wall tiles visible.
2. Selecting a player unit highlights its reachable tiles in blue, and forest tiles cost more.
3. Moving animates tile by tile and routes around walls.
4. The action menu opens after the move, with Attack disabled when nothing is in reach.
5. Choosing Attack highlights valid targets in red; hovering one shows `Deals 6-8   Hit 85%   Crit 21%`.
6. Attacking damages the target, the HP bar shrinks, and an adjacent survivor counters.
7. The Archer attacking from two tiles away takes **no** counter from a reach-1 enemy.
8. Once every player unit has acted, the enemy turn runs on its own — units advance and attack.
9. Killing all three enemies shows **Victory**; losing all three players shows **Defeat**.
10. The seed is printed to the console at battle start.

**Play it until you win, then restart and lose on purpose.** Both endings must be reachable. If either cannot be reached, that is a bug — report it rather than adjusting stats to hide it.

- [ ] **Step 6: Tune**

Now that it is playable, adjust only the numbers in `Scenario` and, if the swing feels wrong, `Combat.DAMAGE_VARIANCE`. Target: a battle lasting roughly 4-6 turns where losing is possible but not likely with decent play.

If three layers of randomness read as noisy rather than tense, `DAMAGE_VARIANCE = 0.0` removes damage spread while leaving hit and crit intact. That is a one-constant change and was anticipated in the spec.

- [ ] **Step 7: Mark the spec implemented**

Change the spec's status line to:

```markdown
- **Status:** Implemented — see `docs/superpowers/plans/2026-08-30-sortie-vertical-slice.md`
```

- [ ] **Step 8: Commit and open the pull request**

```bash
git add -A
git commit -m "feat: add the opening scenario and tune the vertical slice

Six units on a 10x8 map. The Archer's reach of 2 is the tactical hook:
it can strike without being countered, but it is fragile when caught.

Co-authored-by: Claude Opus 5 <noreply@anthropic.com>"

git push -u origin feature/tactics-vertical-slice
gh pr create --fill
```

Then, per the repository conventions, return to `main` and delete the local branch:

```bash
git checkout main
git branch -d feature/tactics-vertical-slice
```

---

## Definition of Done

- `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit` exits 0 with every test passing.
- The game launches, plays through to **Victory**, and plays through to **Defeat**.
- No file under `core/` references a `Node`, a scene, or `Input`.
- No file under `core/` calls `randf()`, `randi()`, or `randomize()` outside `RealRollSource`.
- The battle seed is printed at start and the same seed reproduces the same battle.
