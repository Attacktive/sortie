# Sortie

A grid-tactics JRPG vertical slice built in Godot 4.7.2 and GDScript.

---

## Run it

```sh
godot --headless --import   # once on a fresh clone; GUT's class_names need the import cache
godot                       # play the game (boots to title screen)
godot scenes/field.tscn     # walk around field standalone
godot scenes/battle.tscn    # play battle standalone
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit   # test
```

The first and the last of those are what `.github/workflows/tests.yaml` runs on a fresh Ubuntu runner against a pinned Godot 4.7.2, so the workflow doubles as executable documentation for the setup. GUT exits non-zero on any failure, so the build breaks on its own.

There is also a screenshot harness, gated on environment variables so it never runs in normal play:

```sh
SORTIE_SHOT=out.png godot --quit-after 300                       # capture title screen
SORTIE_SHOT=out.png SORTIE_TITLE_SELECT=ui_down godot --quit-after 300 # capture title selection
SORTIE_SHOT=out.png SORTIE_SELECT=9,1 godot --quit-after 300     # capture with a unit inspected
SORTIE_SHOT=out.png SORTIE_ATTACK=0,7,8,0 SORTIE_WAIT=0.32 godot --quit-after 400   # capture mid-swing
SORTIE_SHOT=out.png SORTIE_WALK=0,6,3,4 SORTIE_WAIT=0.55 godot --quit-after 600      # capture battle walk mid-stride
SORTIE_SHOT=out.png SORTIE_FIELD_WALK=right SORTIE_WAIT=0.40 godot scenes/field.tscn --quit-after 600 # capture field walk
SORTIE_SHOT=out.png SORTIE_FIELD_WALK=right SORTIE_FIELD_TURN=down,0.40 SORTIE_WAIT=0.42 godot scenes/field.tscn --quit-after 600 # capture field turn
SORTIE_SHOT=out.png SORTIE_FIELD_INTERACT=true SORTIE_WAIT=0.10 godot scenes/field.tscn --quit-after 300 # capture dialogue interaction
SORTIE_SHOT=out.png SORTIE_FIELD_TRIGGER=true SORTIE_WAIT=0.10 godot scenes/field.tscn --quit-after 300 # capture trigger event execution
SORTIE_SHOT=out.png SORTIE_FIELD_MENU=true godot scenes/game.tscn --quit-after 300 # capture field pause menu
SORTIE_SHOT=out.png SORTIE_SAVE_MENU=true godot scenes/game.tscn --quit-after 300  # capture save slot selector
SORTIE_SHOT=out.png SORTIE_MISSION_BRIEF=true godot scenes/game.tscn --quit-after 300 # capture Sir Roderick mission briefing
SORTIE_SHOT=out.png SORTIE_BATTLE_BANTER=true godot scenes/game.tscn --quit-after 300 # capture Turn 1 combat banter
```

It lives in `scenes/screenshot_probe.gd`. It is a development affordance rather than a feature, and it stays: it is how every visual claim in this project was verified instead of asserted. Vary `SORTIE_WAIT` across several runs and stack the results to inspect an animation frame by frame — a single capture proves a frame drew, not that a cycle plays.

---

## Architecture in one paragraph

Two layers, one bridge. Everything in `core/` is plain `RefCounted`/`Resource` with no `Node`, scene, or `Input` reference, so the whole rules engine runs and tests headless. Everything in `scenes/` and `ui/` renders state and forwards input. `scenes/battle.gd` bridges input, the core engine, and presentation via a view-side state machine.

Two boundary invariants are enforced in CI by the `Check core boundary invariants` step in `.github/workflows/tests.yaml` before Godot installation, ensuring any leakage fails in seconds rather than minutes:

- No `Node`, `get_tree()`, `Input`, `preload()`, or `.tscn` references anywhere in `core/`.
- All randomness in `core/` must be injected; no `randf`, `randi`, or `randomize` calls are permitted outside `core/real_roll_source.gd`.

---

## Map of the code

| Path | Responsibility |
| --- | --- |
| `core/terrain.gd` | Terrain enum plus cost / defence / evasion lookups |
| `core/unit_data.gd` | `Resource`: stats, team, animation sheet paths |
| `core/battle_unit.gd` | Runtime combat unit state — hp, cell, has_acted |
| `core/battle_grid.gd` | Battle grid tiles, terrain, occupancy, ASCII board construction |
| `core/movement_field.gd` | Dijkstra flood fill results: costs and paths |
| `core/movement.gd` | Flood fill, attack-range geometry, threat reach maps |
| `core/roll_source.gd` + `real_` + `scripted_` | Injectable randomness interface, seeded PRNG, and deterministic scripted roll queue |
| `core/attack_forecast.gd` / `attack_result.gd` / `combat_exchange.gd` | Combat value types and exchange outcomes |
| `core/combat.gd` | Pure combat forecast, hit/crit/variance resolution, and exchange mechanics |
| `core/turn_order.gd` | Turn phase state machine, spent-unit accounting, and victory/defeat detection |
| `core/ai_decision.gd` / `enemy_ai.gd` | Expected-value target scoring with kill bonuses and deterministic tie-breaking |
| `core/scenario.gd` | Default vertical slice map and six-unit battle roster |
| `core/facing.gd` | The four LPC sprite sheet rows and direction conversions (`from_motion`, `toward`) |
| `core/field_map.gd` | The walkable field world from ASCII: dimensions, solidity, glyphs, box-to-tile overlap, dynamic mutation |
| `core/field_body.gd` | Sub-stepped, axis-separated movement, map collision, and dynamic obstacle avoidance |
| `core/dialogue_choice.gd` / `dialogue_node.gd` / `dialogue_tree.gd` | Dialogue tree data model supporting text, speaker IDs, and conditional choices |
| `core/dialogue_runner.gd` | Headless state machine traversing dialogue trees |
| `core/interaction.gd` | Geometry probe calculations for directional NPC/object interaction |
| `core/world_state.gd` | Key-value story state container supporting boolean flags, integer counts, and string states |
| `core/event_condition.gd` | Comparison evaluations against a `WorldState` |
| `core/event_action.gd` | Atomic trigger actions (flag mutation, dialogue, tile changes, battle initiation) |
| `core/event_trigger.gd` | Step and interact trigger definitions with spatial cells, conditions, and actions |
| `core/trigger_registry.gd` | Spatial index mapping grid cells to step and interact triggers |
| `core/mission_data.gd` | Mission configuration model (mission ID, title, briefing, field/battle maps, rosters, victory/defeat flags) |
| `core/mission_registry.gd` | Mission factory registering campaign sorties (`M01_CABBAGE`) |
| `core/save_data.gd` | Serializable save data structure with schema validation |
| `core/save_manager.gd` | Atomic filesystem persistence (`user://saves/`) with slot summaries and corruption safeguards |
| `scenes/game.gd` / `game.tscn` | Root game coordinator managing transitions between Title, Field, and Battle while preserving state |
| `scenes/title.gd` / `title.tscn` | Title screen scene hosting the main menu |
| `scenes/field.gd` / `field.tscn` | Field mode scene assembling map, view, player, camera, NPCs, triggers, pause menu, and state capture/restore |
| `scenes/field_player.gd` | Field character controller translating input into velocity, driving LPC walk cycle and facing |
| `scenes/field_npc.gd` | NPC actor on the field with sprite sheet, collision box, facing, and dialogue tree |
| `scenes/field_view.gd` | Field map renderer drawing ground and solid tiles from atlas textures with deterministic grass variants |
| `scenes/battle.gd` / `battle.tscn` | Turn-based tactics combat scene bridging input, rules engine, and presentation state machine |
| `scenes/grid_view.gd` | Battle terrain, movement overlay, attack overlay, and threat reach rendering |
| `scenes/unit_view.gd` | Battle unit rendering: directional LPC animations (walk, swing), health bar, damage flash, death fade |
| `scenes/cursor.gd` | Battle board cursor supporting keyboard navigation and mouse hover/selection |
| `scenes/combat_animator.gd` | Sequences resolved combat exchanges (strike animation, damage number, sound, death) |
| `scenes/sfx.gd` | Audio manager with outcome-to-clip routing, round-robin voice pool, and pitch variation |
| `scenes/grid_geometry.gd` | Cell coordinate and pixel position conversions for 64px LPC grid |
| `scenes/screenshot_probe.gd` | Visual regression capture harness gated by environment variables |
| `ui/title_menu.gd` | Title screen menu options (New Game, Load Game, Quick Battle, Quit) |
| `ui/field_menu.gd` | Field pause menu (Save, Load, Title, Resume) |
| `ui/save_slot_menu.gd` | 10-slot save/load management UI with metadata inspection and confirmation dialogs |
| `ui/dialogue_box.gd` | Dialogue presentation layer for speaker names, body text, and interactive choices |
| `ui/transition_layer.gd` | Fullscreen screen fader and 3-beat battle flash transition coordinator |
| `ui/action_menu.gd` | Unit battle action selection menu (Attack, Wait, Cancel) |
| `ui/forecast_panel.gd` | Combat pre-battle forecast HUD (hit chance, damage range, crit chance) |
| `ui/forecast_format.gd` | Formatting utilities for combat forecast strings |
| `ui/damage_number.gd` | Floating combat feedback popups (damage, crits, misses) |
| `ui/turn_banner.gd` | Player/Enemy phase transition banner animation |
| `ui/result_screen.gd` | Victory and defeat summary modals with retry and continue actions |
| `assets/lpc/` | Characters and terrain, CC-BY-SA 3.0 / GPL 3.0 — `assets/lpc/ATTRIBUTION-tile-atlas.txt` must not be deleted |
| `assets/audio/` | Three CC0 combat sounds, with `CREDITS.md` recording which original became which clip |
| `test/` | GUT test suite covering rules, scene wiring, menus, audio, save/load, and real input events; `test_full_battle.gd` provides headless auto-battle simulation |
| `docs/DESIGN-NOTES.md` | Non-re-litigated design decisions, known risks, and implementation bug postmortems |
| `docs/superpowers/specs/` + `plans/` | Design specifications and implementation plans for each completed sub-project |

---

## Licenses

- Source code is released under the MIT License.
- Character and terrain sprite artwork in `assets/lpc/` is licensed under CC-BY-SA 3.0 / GPL 3.0. The attribution file `assets/lpc/ATTRIBUTION-tile-atlas.txt` must not be deleted.
- Audio sound effects in `assets/audio/` are Kenney RPG Audio (CC0). See `assets/audio/CREDITS.md` for clip source mapping.
