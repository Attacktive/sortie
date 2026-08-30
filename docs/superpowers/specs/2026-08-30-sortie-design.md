# Sortie — Design Spec

- **Date:** 2026-08-30
- **Status:** Implemented — see `docs/superpowers/plans/2026-08-30-sortie-vertical-slice.md`
- **Engine:** Godot 4.7.2 stable, GDScript

## 1. Purpose

Sortie is a grid-tactics RPG vertical slice.
Its only job is to answer whether the core tactical loop is fun, before any content, story, or progression gets built around it.

**Done means:** you launch the game, play one battle through to victory, play another through to defeat, and every test passes headless.

**Explicit non-goals for this slice:** story, save/load, leveling, unit recruitment, multiple maps, class systems, permadeath, sound, and final art.
Each of those is a separate project with its own spec.

## 2. Core loop

Player turn begins.
Select a unit, see its reachable tiles highlighted, move it, pick a target within attack range, resolve the attack.
That unit is now spent.
Repeat until every living player unit has acted, or the player ends the turn early.

The enemy turn runs the identical rules under AI control.

Repeat until one side has no living units.

## 3. Architecture

Two layers with exactly one bridge between them.

**`core/` — the rules.**
Plain GDScript classes and Resources.
No `Node`, no scene tree, no rendering, no input.
Runs and tests headless.

**`scenes/` and `ui/` — the presentation.**
Nodes that render core state and forward player input.

**`battle.gd` — the bridge.**
The only script that touches both layers.
It queries the core, renders the answers, applies core mutations, and advances the phase machine.

The invariant that keeps this honest: **the core never references a Node, and the view never decides a rule.**

```
res://
	core/
		battle_grid.gd          # tiles, terrain, occupancy
		unit_data.gd            # Resource: stats
		battle_unit.gd          # runtime unit state
		terrain.gd              # terrain enum + cost/defense/evasion table
		movement.gd             # flood fill range + pathing
		combat.gd               # hit / crit / variance resolution + forecast
		turn_order.gd           # phase state machine
		enemy_ai.gd             # expected-value target scoring
		roll_source.gd          # injectable randomness contract
		real_roll_source.gd     # seeded RandomNumberGenerator
		scripted_roll_source.gd # queued literals, for tests
	scenes/
		battle.tscn / battle.gd # orchestrates core + view
		unit_view.tscn          # placeholder sprite, HP bar, path tween
		cursor.tscn             # cell selection
	ui/
		action_menu.tscn        # Attack / Wait
		forecast_panel.tscn     # "Deals 6-8 | Hit 85% | Crit 21%"
		result_screen.tscn      # Victory / Defeat
	test/
		test_movement.gd
		test_combat.gd
		test_turn_order.gd
		test_enemy_ai.gd
```

## 4. Data model

### `UnitData` (Resource)

| Field | Type | Notes |
|---|---|---|
| `unit_name` | `String` | |
| `max_hp` | `int` | |
| `attack` | `int` | |
| `defense` | `int` | |
| `accuracy` | `float` | `[0.0, 1.0]` |
| `evasion` | `float` | `[0.0, 1.0]` |
| `crit_rate` | `float` | `[0.0, 1.0]` |
| `move_range` | `int` | in movement cost, not tiles |
| `attack_range` | `int` | measured in Manhattan distance |
| `team` | `Team` | `PLAYER` or `ENEMY` |
| `color` | `Color` | placeholder art only |

### `BattleUnit` (RefCounted)

Runtime state: `data`, `hp`, `cell`, `has_acted`, `team`, plus `is_alive()`.

### Terrain

| Terrain | Move cost | Defense | Evasion |
|---|---|---|---|
| Plain | 1 | +0 | +0.00 |
| Forest | 2 | +2 | +0.20 |
| Wall | impassable | — | — |

Three types is the minimum for terrain to matter, and Forest mattering in *two* dimensions gives positioning real weight.

### `BattleGrid` (RefCounted)

Holds `size: Vector2i`, a terrain array indexed by cell, and a `Vector2i -> BattleUnit` occupancy dictionary.
Exposes `is_in_bounds()`, `terrain_at()`, `unit_at()`, `place_unit()`, `move_unit()`, and `units_of_team()`.

## 5. Movement

Movement range is a **Dijkstra flood fill** from the unit's cell, bounded by `move_range` in accumulated movement cost.

- Walls are impassable.
- Enemy-occupied cells block movement entirely.
- Ally-occupied cells are passable but not landable.
- A single pass produces both the reachable set and a predecessor map, so `path_to()` is just a walk backward through predecessors.

`AStarGrid2D` is **not** used for range calculation, because range requires a cost-limited flood fill rather than a single shortest path.
It is used separately by the enemy AI to path toward targets that sit beyond move range.

API:

- `reachable_cells(grid, unit) -> Dictionary` — cell to accumulated cost
- `path_to(grid, unit, target) -> Array[Vector2i]` — empty when unreachable
- `attackable_cells(grid, unit, from_cell) -> Array[Vector2i]`

## 6. Combat

Randomness enters through an **injected roll source**, so gameplay is random while tests stay deterministic.

```gdscript
class_name RollSource
## Returns a float in [0.0, 1.0).
func roll_unit() -> float:
	return 0.0
```

`RealRollSource` wraps a seeded `RandomNumberGenerator` and forwards to `randf()`.
`ScriptedRollSource` returns queued literals in order, which makes each test state its intent instead of relying on a magic seed.

### Constants

```gdscript
const CRIT_MULTIPLIER := 3
const DAMAGE_VARIANCE := 0.1  # +/- fraction; 0.0 disables variance entirely
```

### Resolution

Exactly three rolls, drawn in this fixed order and consumed **conditionally** — a miss draws exactly one:

```gdscript
hit_chance = clampf(attacker.accuracy - (defender.evasion + terrain_evasion), 0.0, 1.0)
hit        = roll_unit() < hit_chance
crit       = roll_unit() < attacker.crit_rate
variance   = 1.0 - DAMAGE_VARIANCE + roll_unit() * 2.0 * DAMAGE_VARIANCE

raw  = attacker.attack - (defender.defense + terrain_defense)
base = maxi(1, roundi(raw * variance))

var multiplier := 1
if crit:
	multiplier = CRIT_MULTIPLIER

final = base * multiplier
```

Both `terrain_evasion` and `terrain_defense` are read from the **defender's** cell.

The damage floor of 1 applies **before** the crit multiplier, so a crit is always a clean 3x of what the hit would otherwise have dealt.

Because `roll_unit()` is half-open, both extremes are exact with no fencepost handling: `hit_chance == 1.0` always hits, and `hit_chance == 0.0` always misses.

### Counterattack

If the defender survives and the attacker's cell falls within the defender's attack range, the defender counters as a **full independent attack** — its own hit, crit, and variance rolls.

### Forecast

`forecast()` is pure and RNG-free.
It returns `hit_chance`, `crit_chance`, and minimum/maximum damage bounds, and it consumes **no rolls**.
This is what makes the player-facing panel truthful.

### Seeding

The battle constructs `RealRollSource` with an explicit seed that is logged at battle start, so any battle can be replayed exactly.

Roll order is therefore **part of the contract**, not an implementation detail: changing it invalidates saved seeds, so the tests pin it.

## 7. Turn order

Phases: `PLAYER_TURN`, `ENEMY_TURN`, `VICTORY`, `DEFEAT`.

A player turn ends when every living player unit has `has_acted`, or when the player ends the turn explicitly.
On each phase transition, `has_acted` resets for the incoming team.

Victory is no living enemy units; defeat is no living player units.
Both are checked after every attack resolution.

## 8. Enemy AI

Decisions are fully deterministic — randomness lives only in the attacks the AI chooses to make.

For each enemy unit, in fixed order:

1. Enumerate reachable cells, and from each, which player units are attackable.
2. Score every `(cell, target)` pair by expected value:
	```gdscript
	ev = hit_chance * avg_damage * (1.0 + crit_rate * (CRIT_MULTIPLIER - 1))
	```
	where `avg_damage` is the variance midpoint, which is simply the unmodified `raw` damage.
	A `KILL_BONUS` is added when maximum damage would meet or exceed the target's current HP.
3. Take the highest-scoring pair, breaking ties by lowest cell coordinate so behavior is reproducible.
4. When nothing is reachable, path toward the nearest player unit with `AStarGrid2D` and advance as far along that path as `move_range` allows.

## 9. Presentation

- `TileMapLayer` for terrain, a second `TileMapLayer` for the highlight overlay — blue for movable, red for attackable.
- Cursor node supporting both keyboard (arrows/WASD, confirm, cancel) and mouse cell selection.
- `UnitView`: placeholder `ColorRect` plus an HP bar, with `walk_path(path)` tweening along the path and emitting `walk_finished`.
- `ActionMenu`: Attack / Wait.
- `ForecastPanel`: renders `Deals 6-8 | Hit 85% | Crit 21%`, formatting floats to percentages at the UI edge only.
- `ResultScreen`: Victory or Defeat, with restart.

**Data flow:** input reaches `battle.gd`, which runs a core *query*, renders highlights, waits for confirmation, applies a core *mutation*, plays the view tween, receives `walk_finished`, and advances the phase machine.

## 10. Error handling

Core functions are **total**: out-of-bounds cells and unreachable targets return empty results rather than crashing.

`assert()` guards the invariants — a unit occupies exactly one cell, no two units share a cell, HP never goes negative, and a `ScriptedRollSource` is never over-drawn.

Because the view holds no rules, there is no duplicated state that can drift out of sync with the core.

## 11. Testing

GUT, run headless:

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
```

**`test_movement.gd`** — move cost is respected; walls are impassable; enemies block; allies are passable but not landable; an unreachable target yields an empty path.

**`test_combat.gd`** — a miss consumes one roll and deals nothing; hit without crit; a crit triples damage; the crit threshold is false at exactly `crit_rate` and true just below it; variance at both bounds; the damage floor of 1 holds against heavy armor; the floor applies before the crit multiplier; terrain evasion lowers hit chance; `hit_chance` of 1.0 always hits and 0.0 always misses; counters roll independently; `forecast()` consumes no rolls.

**`test_turn_order.gd`** — the turn ends when all units have acted; explicit end-turn works; `has_acted` resets on transition; victory and defeat are detected.

**`test_enemy_ai.gd`** — attacks when a target is reachable; prefers the higher-EV target; prefers a kill; advances toward the nearest target when none is reachable; tie-breaking is deterministic.

## 12. Repository

Initialized as a local git repo on `main`, with `.godot/`, `.idea/`, and `.DS_Store` ignored.

Implementation lands on `feature/tactics-vertical-slice` and ships as a pull request once a remote exists.
**No remote is configured yet** — creating the GitHub repository is the user's call, not something this spec assumes.

## 13. Milestones

1. Godot project scaffold, GUT installed, headless test run green on an empty suite
2. `core`: `BattleGrid`, `UnitData`, `BattleUnit`, terrain table
3. `core`: movement flood fill and pathing
4. `core`: `RollSource` family, combat resolution, forecast
5. `core`: turn phases, victory/defeat detection
6. `core`: enemy AI scoring
7. `scenes`: terrain render, unit views, cursor, highlight overlay
8. `ui`: action menu, forecast panel, result screen
9. `battle.gd` wiring the whole loop end to end
10. Tuning pass on stats, terrain values, crit rate, and variance

## 14. Open risks

**~~GUT may not yet support Godot 4.7.~~ Resolved.**
GUT 9.7.1 is verified working on Godot 4.7.2 as of milestone 1: it reports failures with message and line number, and exits 1 on failure so CI can trust the exit code.
The one wrinkle is a required one-time `godot --headless --import` pass — without it a fresh project has no import cache, GUT's `class_name` registrations do not exist, and `gut_cmdln.gd` aborts before running anything.
No fallback to gdUnit4 is needed.

**Three layers of randomness may read as noisy rather than tense in play.**
`DAMAGE_VARIANCE` is a single constant; setting it to `0.0` removes damage spread without touching any logic.
This was a deliberate, informed choice and is a tuning question, not a design flaw.
