# Sortie — Mode Flow & Battle Handoff Design Spec

- **Date:** 2026-09-05
- **Status:** Draft, pending user review
- **Engine:** Godot 4.7.2 stable, GDScript
- **Precedes:** `2026-08-31-sortie-events-design.md` built triggers, flags, and world state; this unites standalone Field and Battle scenes into a unified game flow

## 1. Purpose

Currently, Sortie contains two rich, fully tested, but disconnected gameplay scenes:

1. `scenes/battle.tscn`: Standalone grid tactics battle mode (movement, attack, AI, animations, audio).
2. `scenes/field.tscn`: Standalone JRPG exploration mode (8-way movement, collision, camera, NPC dialogue, world flags, step/interact triggers).

Sub-project 4 builds the **Mode Flow & Battle Handoff** infrastructure that unites them into a playable vertical slice loop:

1. **Title Scene & Menu**: Entry point with "New Game", "Quick Battle" (direct leap to combat for testing), and "Quit".
2. **Root Game Coordinator**: Top-level `Game` node (`scenes/game.tscn` / `scenes/game.gd`) managing active scene lifecycle, owning persistent `WorldState`, and retaining field restore snapshots.
3. **Field-to-Battle Handoff**: `EventAction.Type.START_BATTLE` triggering visual transition from exploration into combat while capturing player position and orientation.
4. **Battle-to-Field Return**: On victory, transitioning back to field exploration, restoring player position/facing, and updating world state flags.
5. **Defeat & Retry Flow**: On defeat, offering "Retry Battle" (immediate restart) and "Return to Title".
6. **Shared Transition Layer**: Visual flash/fade screen transitions that run at full speed during interactive play and zero duration (0s) under headless GUT tests.

**Done means:**

- Booting `godot` launches `scenes/game.tscn` showing the Title Screen.
- Selecting "New Game" transitions to Field Mode at the default spawn cell.
- Stepping on a designated encounter trigger or interacting with an encounter prop transitions to Battle Mode via visual battle flash/fade.
- Winning the battle returns to Field Mode, restoring player coordinates and facing, with world state updated (e.g. encounter trigger exhausted or flag set).
- Losing the battle allows immediate retry or returning to Title Screen.
- Selecting "Quick Battle" from Title Screen boots directly into battle without field overhead.
- All headless GUT tests pass (0s transition duration, no hanging tweens/timers).
- Two-layer architecture strictly maintained (core remains RefCounted with zero engine leaks).

**Explicit non-goals for this sub-project:**

- Disk save/load file persistence (Sub-project 5).
- Multiple distinct battle maps or parties (Sub-project 6).
- Party management or inventory screen (Sub-project 6).

---

## 2. Where this sits

Story mode roadmap:

| # | Sub-project | Status | Delivers |
| --- | --- | --- | --- |
| 1 | Field mode | Done, PRs #8–#14 | Walkable map, collision, camera |
| 2 | Interaction & dialogue | Done, PR #16 | Facing interaction, dialogue box, branching choices |
| 3 | Events & world state | Done, PRs #17, #24, #26 | Step/interact triggers, world flags, conditional choices, tile mutation |
| **4** | **Mode flow & battle handoff** | **This spec** | Title $\leftrightarrow$ Field $\leftrightarrow$ Battle lifecycle, transitions, defeat flow |
| 5 | Save & load | Next | Disk persistence of WorldState, party data, restore snapshot |
| 6 | Content | Later | World maps, intro story script, boss encounter, victory fanfare |

---

## 3. Architecture

Following the project's two-layer architecture, `Game` acts as the presentation coordinator while `WorldState` remains pure domain state in `core/`:

```text
┌─────────────────────────────────────────────────────────────┐
│                           GAME                              │
│                                                             │
│  scenes/game.tscn (Node2D, application main_scene)          │
│    ├── world_state: WorldState                              │
│    ├── field_restore_state: Dictionary                      │
│    ├── _scene_container: Node2D                             │
│    │     └── [ Title | Field | Battle ] (one active child)  │
│    └── _transition: TransitionLayer (CanvasLayer)           │
│          └── _color_rect: ColorRect                         │
└─────────────────────────────────────────────────────────────┘
```

### Flow Diagram

```text
                 ┌──────────────┐
                 │ Title Screen │
                 └──────┬───────┘
                        │
       ┌────────────────┴────────────────┐
   "New Game"                     "Quick Battle"
       ▼                                 ▼
┌──────────────┐                  ┌──────────────┐
│  Field Mode  │                  │ Battle Mode  │
└──────┬───────┘                  └──────┬───────┘
       │                                 │
 (Encounter Trigger)                     │
       ▼                                 │
┌──────────────┐                         │
│ Battle Mode  │                         │
└──────┬───────┘                         │
       │                                 │
       ├──────────────┬──────────────────┤
    Victory         Defeat             Defeat
       ▼              ▼                  ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ Restore to   │ │ Retry Battle │ │ Return to    │
│  Field Mode  │ │ (immediate)  │ │ Title Screen │
└──────────────┘ └──────────────┘ └──────────────┘
```

---

## 4. Components & Interfaces

### 4.1. Transition Layer (`ui/transition_layer.gd`)

A dedicated `CanvasLayer` (layer 100) holding a full-screen `ColorRect` for animated transitions.

```gdscript
class_name TransitionLayer
extends CanvasLayer

signal fade_out_completed
signal fade_in_completed

func fade_out(duration: float = 0.25, color: Color = Color.BLACK) -> void
func fade_in(duration: float = 0.25) -> void
func battle_flash(callback_on_black: Callable, test_instant: bool = false) -> void
```

- **Battle Flash Rhythm:**
  - White flash (0.06s) $\rightarrow$ transparent (0.06s) $\rightarrow$ white flash (0.06s) $\rightarrow$ fade to black (0.25s).
  - Invokes `callback_on_black` while screen is fully black.
  - Fade from black back to clear (0.25s).
- **Headless Test Mode:**
  - If `test_instant` is true (or running headless), duration is set to 0.0s and callback executes immediately without awaiting process frames.

### 4.2. Title Screen (`scenes/title.tscn` / `ui/title_menu.gd`)

A clean menu matching the project's minimal pixel/panel style:

- Title banner: "SORTIE".
- Vertical button list:
  1. `New Game` $\rightarrow$ emits `new_game_requested`
  2. `Quick Battle` $\rightarrow$ emits `quick_battle_requested`
  3. `Quit` $\rightarrow$ calls `get_tree().quit()`
- Keyboard navigation (`ui_up`, `ui_down`, `ui_accept`) with visual selection highlighting.

### 4.3. EventAction: Start Battle (`core/event_action.gd`)

Extend `EventAction.Type`:

```gdscript
enum Type { SET_FLAG, SHOW_DIALOGUE, MODIFY_TILE, START_BATTLE }

static func start_battle(battle_id: String = "default") -> EventAction:
    return EventAction.new(Type.START_BATTLE, { "battle_id": battle_id })
```

### 4.4. Field Mode Handoff (`scenes/field.gd`)

- Emits signal:

  ```gdscript
  signal battle_requested(battle_id: String, restore_state: Dictionary)
  ```

- Generates restore state dictionary:

  ```gdscript
  {
      "cell": current_cell,
      "facing": _player.facing,
  }
  ```

- Freezes player and input during battle transition.
- Supports method `restore(restore_state: Dictionary)`:
  - Repositions player sprite to `restore_state.cell`.
  - Sets player facing direction to `restore_state.facing`.
  - Centers camera immediately on restored position.

### 4.5. Battle Mode Integration (`scenes/battle.gd` & `ui/result_screen.gd`)

- `Battle` emits signal:

  ```gdscript
  signal battle_completed(victory: bool)
  signal title_requested
  signal retry_requested
  ```

- `ResultScreen` updated options:
  - **On Victory:** Displays "Victory" and button "Continue" $\rightarrow$ emits `continue_requested`.
  - **On Defeat:** Displays "Defeat" and two buttons:
    - "Retry Battle" $\rightarrow$ emits `retry_requested`.
    - "Return to Title" $\rightarrow$ emits `title_requested`.

### 4.6. Root Game Coordinator (`scenes/game.tscn` / `scenes/game.gd`)

- Application entry point (`application/run/main_scene = "res://scenes/game.tscn"`).
- Manages active child scene in `_scene_container`.
- Holds `world_state: WorldState` across mode changes.
- Coordinates transitions with `_transition_layer`.
- Handlers:
  - `_on_title_new_game()`: Initializes fresh `world_state`, transitions to `Field`.
  - `_on_title_quick_battle()`: Transitions directly to standalone `Battle`.
  - `_on_field_battle_requested(battle_id, restore_state)`: Stores `restore_state`, plays battle flash, transitions to `Battle`.
  - `_on_battle_completed(victory)`:
    - If victory: Sets victory flag in `world_state` (e.g. `"defeated_" + battle_id`), transitions to `Field`, calls `field.restore(restore_state)`.
    - If defeat & retry: Restarts `Battle` with fresh rolls/grid.
    - If defeat & title: Transitions to Title Screen.

---

## 5. Verification Strategy

1. **GUT Unit & Integration Tests**:
   - `test/test_transition_layer.gd`: Verify fade in, fade out, battle flash sequence, and instantaneous test mode.
   - `test/test_event_action_battle.gd`: Verify `EventAction.start_battle` instantiation and type dispatch.
   - `test/test_field_restore.gd`: Verify field accepts restore state and repositions player and facing correctly.
   - `test/test_game_flow.gd`: Comprehensive integration test exercising:
     - Title $\rightarrow$ Field transition.
     - Title $\rightarrow$ Quick Battle transition.
     - Field $\rightarrow$ Battle trigger handoff.
     - Battle victory $\rightarrow$ Field restoration with updated world state flag.
     - Battle defeat $\rightarrow$ Retry battle and Return to Title.
2. **Headless Safety**:
   - All transition animations must complete in 0.0s when headless or test-flagged.
   - 0 leaks across `core/` boundary invariants.
3. **Interactive Verification**:
   - Verify visually via screenshot harness:
     - Title screen rendering.
     - Battle flash animation frames.
     - Victory return to field.
     - Defeat menu options.
