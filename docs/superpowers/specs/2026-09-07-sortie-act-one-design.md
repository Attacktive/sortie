# Sortie — Act I Design Spec

- **Date:** 2026-09-07
- **Status:** Draft, pending user review
- **Engine:** Godot 4.7.2 stable, GDScript
- **Precedes:** Act II (content and missions)

## 1. Purpose

Implement Act I of Sortie, encompassing missions M02 through M05. This adds the missions to the `core/mission_registry.gd`, updates `scenes/field.gd` with Sir Roderick's sequential briefing chain and Barnaby's dialogue, and introduces the skirmisher archetype stats. It relies on the existing engine capabilities, parameterizing the autobattle harness for balance verification.

## 2. Decisions not in the brief

- **Player roster helper name:** The helper method to generate the four-unit player roster will be named `_get_player_roster() -> Array[UnitData]` and placed in `core/mission_registry.gd`.
- **Dialogue node ID convention:** To ensure node IDs are globally unique across all six of Sir Roderick's trees, they will be prefixed with the mission ID they precede or represent (e.g., `m01_node_1`, `m02_node_1`, `terminal_node_1`).
- **Autobattle parameterization:** Instead of creating a sibling test, the existing `test/test_full_battle.gd` will be parameterized to accept an optional `mission_id` string, defaulting to M01 if absent.

## 3. Mission Balance & Target Win-Rates

Resolving the open question from the story spec regarding M05 Boss Balance:

General Malakor is designed as an unbalanced Range 2 threat (40 HP, 12 Atk) that the melee-heavy squad cannot counter at range. To ensure he is properly balanced, the target win-rate band for M05 in the auto-battle harness is set to **18 to 28 victories out of 40 seeds**.

The target win-rate band for M02, M03, and M04 is set to **24 to 34 victories out of 40 seeds**.

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

A new private helper `_get_player_roster()` will supply the uniform 4-unit player squad to all Act I missions.

Skirmisher unit stats will be initialized directly in the registry via the `_make_unit` function arguments with 30% evasion (`0.30`).

### 4.2. Field Updates (`scenes/field.gd`)

Sir Roderick's `conditional_dialogues` will be updated to a prioritized list of five conditions mapping to the mission flags, ensuring the latest incomplete mission brief is presented:

1. `EventCondition.is_true("mission_m05_completed")` -> Terminal post-victory dialogue.
2. `EventCondition.is_true("mission_m04_completed")` -> M05 Briefing.
3. `EventCondition.is_true("mission_m03_completed")` -> M04 Briefing.
4. `EventCondition.is_true("mission_m02_completed")` -> M03 Briefing.
5. `EventCondition.is_true("mission_m01_completed")` -> M02 Briefing.

The default tree remains the M01 Briefing.

The courtyard mage NPC is renamed to `Barnaby`, receiving a single sequential 3-page dialogue tree without conditionals, replacing the previous breeze behavior.

### 4.3. Test & Harness Adjustments

`test/test_full_battle.gd` will be updated to take a mission ID, running 40 seeds and tallying victories against the balance gate limits.
