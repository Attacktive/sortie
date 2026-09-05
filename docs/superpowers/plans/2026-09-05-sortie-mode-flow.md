# Mode Flow & Battle Handoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the top-level mode coordinator (`Game`), screen transition layer, Title screen, Field-to-Battle trigger handoff, Field restoration upon victory, and Battle defeat/retry flow.

**Architecture:** Presentation and mode switching are orchestrated by `Game` (`scenes/game.gd`), which swaps active child scenes (`Title`, `Field`, `Battle`) under a root container while retaining persistent `WorldState` and field restore coordinates. Transitions run via a dedicated `TransitionLayer` (`ui/transition_layer.gd`). `EventAction.start_battle()` triggers handoff from `core/`.

**Tech Stack:** Godot 4.7.2 stable, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-09-05-sortie-mode-flow-design.md`

## Global Constraints

These apply to every task below:

- **Indent with tabs.** Never spaces.
- **Never hard-wrap for length.** One sentence per physical line, comments included.
- **Single blank lines before and after lists, headings, and dividers.** (MD012 clean).
- **Single blank line between functions in GDScript.**
- **Prefer `if` over the ternary operator.**
- **American English** in prose, comments, and identifiers.
- **`core/` stays free of the scene tree.** After every task, both invariants must produce no output:

  ```sh
  grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
  grep -rlE 'randf|randi|randomize' core/ | grep -v real_roll_source
  ```

- **All existing tests must keep passing.** Run the full suite:

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
  ```

- **A new `.gd` file needs its `.uid` committed.** Run `godot --headless --import` before `git add`.
- **Commits use `feat`/`fix`/`test`/`docs`.** Add the trailer:
  `Co-authored-by: Gemini 3.8 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>`.

---

### Task 1: Screen Transition Layer

Build `TransitionLayer` with configurable color fade and 3-beat battle flash animation, supporting instantaneous completion in tests.

**Files:**

- Create: `ui/transition_layer.gd`
- Create: `test/test_transition_layer.gd`

**Interfaces:**

```gdscript
class_name TransitionLayer
extends CanvasLayer

signal fade_out_completed
signal fade_in_completed

func fade_out(duration: float = 0.25, color: Color = Color.BLACK) -> void
func fade_in(duration: float = 0.25) -> void
func battle_flash(callback_on_black: Callable, test_instant: bool = false) -> void
```

- [ ] Write tests in `test/test_transition_layer.gd`:
  - `test_fade_out_and_fade_in_signals_emit`
  - `test_battle_flash_calls_callback_on_black_and_restores_clear`
  - `test_instant_mode_completes_synchronously_without_hanging`
- [ ] Implement `ui/transition_layer.gd`:
  - CanvasLayer layer 100 with a full-screen `ColorRect` (mouse filter IGNORE).
  - Tween-based fade in and fade out.
  - Battle flash sequence: flash white (0.06s) $\rightarrow$ clear (0.06s) $\rightarrow$ flash white (0.06s) $\rightarrow$ fade black (0.25s) $\rightarrow$ invoke callback $\rightarrow$ fade in (0.25s).
  - When `test_instant` is true or running in headless mode, bypass tweens and invoke callback immediately.
- [ ] Verify tests pass:

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_transition_layer.gd -gexit
  ```

---

### Task 2: EventAction Start Battle

Extend `EventAction` with `START_BATTLE` type.

**Files:**

- Modify: `core/event_action.gd`
- Create: `test/test_event_action_battle.gd`

**Interfaces:**

```gdscript
# In core/event_action.gd
enum Type { SET_FLAG, SHOW_DIALOGUE, MODIFY_TILE, START_BATTLE }

static func start_battle(battle_id: String = "default") -> EventAction:
    return EventAction.new(Type.START_BATTLE, { "battle_id": battle_id })
```

- [ ] Write test `test/test_event_action_battle.gd` verifying `EventAction.start_battle` sets `Type.START_BATTLE` and stores `battle_id`.
- [ ] Modify `core/event_action.gd` to add `START_BATTLE` enum value and static constructor.
- [ ] Run test suite and check `core/` invariants.

---

### Task 3: Title Screen & Menu

Implement `Title` scene and `TitleMenu` component.

**Files:**

- Create: `ui/title_menu.gd`
- Create: `scenes/title.tscn` (or `scenes/title.gd`)
- Create: `test/test_title_menu.gd`

**Interfaces:**

```gdscript
class_name TitleMenu
extends CenterContainer

signal new_game_requested
signal quick_battle_requested
signal quit_requested

func handle_input_action(action: String) -> void
```

- [ ] Write tests in `test/test_title_menu.gd`:
  - Test menu displays "New Game", "Quick Battle", "Quit".
  - Test keyboard navigation (`ui_up`, `ui_down`) moves selection and loops cleanly.
  - Test `ui_accept` on "New Game" emits `new_game_requested`.
  - Test `ui_accept` on "Quick Battle" emits `quick_battle_requested`.
  - Test `ui_accept` on "Quit" emits `quit_requested`.
- [ ] Implement `ui/title_menu.gd` and `scenes/title.gd`.
- [ ] Run tests to verify.

---

### Task 4: Field Mode Handoff & Restoration

Equip `Field` with encounter trigger handling, battle request signal, and player state restoration.

**Files:**

- Modify: `scenes/field.gd`
- Create: `test/test_field_restore.gd`

**Interfaces:**

```gdscript
# In scenes/field.gd
signal battle_requested(battle_id: String, restore_state: Dictionary)

func restore(restore_state: Dictionary) -> void
```

- [ ] Write tests in `test/test_field_restore.gd`:
  - Test `START_BATTLE` action emits `battle_requested` with current player cell and facing.
  - Test `restore(restore_state)` repositions player and sets facing.
  - Test player is frozen during battle transition.
- [ ] Update `scenes/field.gd`:
  - Connect `START_BATTLE` in `_execute_action` to emit `battle_requested`.
  - Add `restore(restore_state: Dictionary)` method.
- [ ] Verify with tests.

---

### Task 5: Battle Result Flow (Victory & Defeat)

Update `Battle` and `ResultScreen` to support victory continuation and defeat retry/title options.

**Files:**

- Modify: `ui/result_screen.gd`
- Modify: `scenes/battle.gd`
- Create: `test/test_battle_result_flow.gd`

**Interfaces:**

```gdscript
# In ui/result_screen.gd
signal continue_requested
signal retry_requested
signal title_requested

# In scenes/battle.gd
signal battle_completed(victory: bool)
signal title_requested
signal retry_requested
```

- [ ] Write tests in `test/test_battle_result_flow.gd`:
  - Test `ResultScreen` on victory shows "Continue" and emits `continue_requested`.
  - Test `ResultScreen` on defeat shows "Retry Battle" and "Return to Title".
  - Test `Battle` forwards signals appropriately.
- [ ] Update `ui/result_screen.gd` and `scenes/battle.gd`.
- [ ] Verify with tests.

---

### Task 6: Root Game Coordinator & Application Main Scene

Assemble `Game` coordinator managing mode transitions and world state preservation.

**Files:**

- Create: `scenes/game.gd`
- Create: `scenes/game.tscn`
- Modify: `project.godot` (update `application/run/main_scene="res://scenes/game.tscn"`)
- Create: `test/test_game_flow.gd`

**Interfaces:**

```gdscript
class_name Game
extends Node2D

var world_state: WorldState
var field_restore_state: Dictionary
```

- [ ] Write integration tests in `test/test_game_flow.gd`:
  - Test game starts at Title screen.
  - Test "New Game" transitions to Field with fresh WorldState.
  - Test "Quick Battle" transitions directly to Battle.
  - Test Field encounter trigger transitions to Battle and saves restore state.
  - Test Battle victory returns to Field, restores position/facing, and records victory flag.
  - Test Battle defeat allows retry or return to Title.
- [ ] Implement `scenes/game.gd` and `scenes/game.tscn`.
- [ ] Update `project.godot` `application/run/main_scene` to `res://scenes/game.tscn`.
- [ ] Run full test suite and verify all tests pass.

---

### Task 7: Visual Verification & Handoff Update

Verify mode flow visually via screenshot probe and update `docs/HANDOFF.md`.

**Files:**

- Modify: `scenes/screenshot_probe.gd`
- Modify: `docs/HANDOFF.md`

- [ ] Add probe hooks for title screen and mode transition in `scenes/screenshot_probe.gd`.
- [ ] Capture visual verification frames.
- [ ] Update `docs/HANDOFF.md` with new test totals, status, and Sub-project 4 completion summary.
- [ ] Verify `docs/HANDOFF.md` markdown formatting and line length.
