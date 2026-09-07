# Sortie — Act I Design Spec

- **Date:** 2026-09-07
- **Status:** Draft, pending user review
- **Engine:** Godot 4.7.2 stable, GDScript
- **Precedes:** `docs/superpowers/specs/2026-09-05-sortie-save-and-load-design.md` added disk persistence and slot management; this adds Act I missions (M02–M05), Sir Roderick's briefing chain, and Barnaby's dialogue

## 1. Purpose

Implement Act I of Sortie, encompassing missions M02 through M05. This adds the missions to `core/mission_registry.gd`, updates `scenes/field.gd` with Sir Roderick's sequential briefing chain and Barnaby's dialogue, and introduces skirmisher archetype stats. It provides a pure grid/unit builder in `core/` shared between the presentation scene and headless testing, parameterizing the auto-battle harness for balance verification.

## 2. Decisions not in the brief

- **Mission titles:** M01 sets `The Cabbage Trajectory`. M02 through M05 are titled:
  - `M02_ALE_RUN`: "The Seasonal Ale Run"
  - `M03_SILVER_SPOONS`: "The Royal Cutlery"
  - `M04_FIELD_OVEN`: "The Tactical Bakery"
  - `M05_SPICE_WARS`: "The Paprika Defense"
- **Player roster helper:** The helper method to generate the four-unit player squad will be declared as `static func _get_player_roster() -> Array[UnitData]` in `core/mission_registry.gd` so `_build_m01_cabbage()` and the new mission builders can invoke it statically.
- **Pure mission builder contract:** To enable headless testing of arbitrary missions without duplicating or drifting from `scenes/battle.gd:79-98`, `MissionRegistry` will expose pure static builders:
  - `static func build_battle_grid(mission: MissionData) -> BattleGrid`
  - `static func populate_units(grid: BattleGrid, mission: MissionData) -> Dictionary`
  Both `scenes/battle.gd` and the headless test harness will call these methods to construct and populate the tactical grid.
- **Dialogue node ID convention:** To preserve compatibility with existing tests that assert M01 node names (`briefing_dishonor`, `post_victory` in `test/test_highspire_courtyard.gd`), M01's node IDs remain unchanged. New trees will use descriptive, mission-prefixed IDs (e.g., `m02_briefing_ale`, `m05_action_sortie`, `terminal_feast`), guaranteeing global uniqueness across all six trees.
- **Autobattle parameterization:** Keep `Scenario` as the default no-argument path in `test/test_full_battle.gd:26-29` to preserve the existing baseline measurements (9.3 team-turns, 75/25 win rate) for the three existing tests. Add a dedicated `_play_mission(mission: MissionData, seed_val: int)` path for testing missions.

## 3. Mission Balance & Target Win-Rates

Resolving the open question from the story spec regarding M05 Boss Balance:

General Malakor is designed as an unbalanced Range 2 threat (40 HP, 12 Atk) that the melee-heavy squad cannot counter at range. To ensure he is properly balanced, the target win-rate band for M05 in the auto-battle harness is set to **18 to 28 victories out of 40 seeds**.

The target win-rate band for M02, M03, and M04 is set to **24 to 34 victories out of 40 seeds**.

Every mission must also reach both outcomes at least once and leave zero battles unresolved.

*Note: Enemy HP and Attack will be adjusted in steps of no more than 3 to fit these bands during implementation. The final numbers and seed tallies will be recorded here.*

| Mission | Target Victories (out of 40) | Actual Victories |
| --- | --- | --- |
| M02_ALE_RUN | 24 to 34 | TBD |
| M03_SILVER_SPOONS | 24 to 34 | TBD |
| M04_FIELD_OVEN | 24 to 34 | TBD |
| M05_SPICE_WARS | 18 to 28 | TBD |

## 4. Components & Contracts

### 4.1. Mission Registry (`core/mission_registry.gd`)

Four new missions added to `MissionRegistry.get_mission(id)`:

- `M02_ALE_RUN`
- `M03_SILVER_SPOONS`
- `M04_FIELD_OVEN`
- `M05_SPICE_WARS`

A private static helper `_get_player_roster() -> Array[UnitData]` will supply the uniform 4-unit player squad to all Act I missions.

Skirmisher unit stats will be initialized directly in the registry via the `_make_unit` function arguments with 30% evasion (`0.30`).

Static domain builder methods will be exposed on `MissionRegistry`:

```gdscript
static func build_battle_grid(mission: MissionData) -> BattleGrid:
    return BattleGrid.from_ascii(mission.map_ascii)

static func populate_units(grid: BattleGrid, mission: MissionData) -> Dictionary:
    # Returns {"players": Array[BattleUnit], "enemies": Array[BattleUnit]}
    # Pairs player_roster[i] with player_spawns[i] and enemy_roster[i] with enemy_spawns[i]
```

`scenes/battle.gd:79-98` will be refactored to call `build_battle_grid()` and `populate_units()`, then instantiate `UnitView` nodes for the placed units.

### 4.2. Field Updates (`scenes/field.gd`)

Sir Roderick's `conditional_dialogues` will be updated to a prioritized list of five conditions mapping to the mission flags, ensuring the latest incomplete mission brief is presented:

1. `EventCondition.is_true("mission_m05_completed")` -> Terminal post-victory dialogue (no choices).
2. `EventCondition.is_true("mission_m04_completed")` -> M05 Briefing.
3. `EventCondition.is_true("mission_m03_completed")` -> M04 Briefing.
4. `EventCondition.is_true("mission_m02_completed")` -> M03 Briefing.
5. `EventCondition.is_true("mission_m01_completed")` -> M02 Briefing.

The default tree remains the M01 Briefing.

The courtyard mage NPC node currently named `FieldNpc` with speaker label `Mage` will both be renamed to `Barnaby`. Its dialogue becomes a single sequential 3-page tree without conditionals. The ambient breeze step trigger tile and its dialogue box text remain untouched; only the NPC's `felt_breeze` conditional tree is removed.

### 4.3. Test & Harness Adjustments

`test/test_full_battle.gd` will retain its parameterless `_play(seed_val: int)` method calling `Scenario.build_grid()` and `Scenario.populate()`.

A new test method `_play_mission(mission: MissionData, seed_val: int) -> Dictionary` will execute headless battles by calling `MissionRegistry.build_battle_grid(mission)` and `MissionRegistry.populate_units(grid, mission)`.

The balance gate test will run 40 seeds for each mission, asserting:

- Victories within target bands (24–34 for M02–M04, 18–28 for M05).
- Both victory and defeat reached at least once (`victories > 0` and `defeats > 0`).
- Zero unresolved battles (`unresolved == 0`).
- A `gut.p()` tally line printed per mission for recording in documentation.
