# Save & Load Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Save & Load persistence subsystem: pure domain `SaveData` schema, atomic disk `SaveManager` with slot summaries across 10 slots, `FieldMenu` pause overlay, `SaveSlotMenu` slot selector, Title screen loading, and full game state rehydration.

**Architecture:** Following the project's two-layer architecture, `SaveData` and `SaveManager` remain decoupled in `core/` (pure `RefCounted` domain logic, zero Node dependencies). Atomic disk writes (.tmp file rename) prevent corrupted files. `FieldMenu` and `SaveSlotMenu` provide keyboard-navigable UI in `ui/`. `Game` coordinates saving snapshots, loading slots, screen transitions, and field rehydration.

**Tech Stack:** Godot 4.7.2 stable, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-09-05-sortie-save-and-load-design.md`

## Global Constraints

These apply to every task below:

- **Indent with tabs.** Never spaces.
- **Never hard-wrap for length.** One sentence per physical line, comments included.
- **Single blank lines before and after lists, headings, and dividers.** (MD012 clean).
- **Single blank line between functions in GDScript.**
- **Prefer `if` over the ternary operator.**
- **American English** in prose, comments, and identifiers.
- **`core/` stays free of the scene tree.** After every task touching `core/`, both invariants must produce no output:

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

### Task 1: Core SaveData Domain Model

Build `SaveData` in `core/save_data.gd` to represent save file contents with validation, versioning, and dictionary round-trip conversion.

**Files:**

- Create: `core/save_data.gd`
- Create: `test/test_save_data.gd`

**Interfaces:**

```gdscript
class_name SaveData
extends RefCounted

const CURRENT_VERSION := 1

var version: int = CURRENT_VERSION
var slot_id: int = 1
var timestamp: String = ""
var playtime_seconds: float = 0.0
var location_name: String = "Overworld"
var party_leader: String = "Vanguard"
var world_state_data: Dictionary = {}
var field_state_data: Dictionary = {}

func to_dict() -> Dictionary
static func from_dict(dict: Dictionary) -> SaveData
static func validate_dict(dict: Dictionary) -> bool
```

- [ ] **Step 1: Write failing tests in `test/test_save_data.gd`:**
  - `test_save_data_to_dict_and_from_dict_round_trip`
  - `test_validate_dict_rejects_missing_keys_or_invalid_types`
  - `test_validate_dict_rejects_slot_id_out_of_bounds`
  - `test_from_dict_returns_null_on_invalid_data`
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_save_data.gd -gexit
  ```

- [ ] **Step 3: Implement `core/save_data.gd`:**
  - Define `class_name SaveData extends RefCounted`.
  - Implement properties, `to_dict()`, `from_dict()`, and `validate_dict()`.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_save_data.gd -gexit
  ```

- [ ] **Step 5: Verify core invariants and commit:**

  ```sh
  godot --headless --import
  git add core/save_data.gd* test/test_save_data.gd*
  git commit -m "feat: implement SaveData domain model and validation"
  ```

---

### Task 2: Core SaveManager Service (Atomic Disk Persistence & Slot Summaries)

Build `SaveManager` in `core/save_manager.gd` to handle reading/writing save files atomically to disk and generating slot summaries.

**Files:**

- Create: `core/save_manager.gd`
- Create: `test/test_save_manager.gd`

**Interfaces:**

```gdscript
class_name SaveManager
extends RefCounted

const MAX_SLOTS := 10
const DEFAULT_SAVE_DIR := "user://saves"

var base_dir: String = DEFAULT_SAVE_DIR

enum Result {
    OK,
    ERR_INVALID_SLOT,
    ERR_FILE_WRITE,
    ERR_FILE_READ,
    ERR_PARSE_JSON,
    ERR_VALIDATION_FAILED,
}

func get_slot_path(slot_id: int) -> String
func save_slot(data: SaveData) -> Result
func load_slot(slot_id: int) -> SaveData
func delete_slot(slot_id: int) -> bool
func get_slot_summaries() -> Array[Dictionary]
func get_slot_summary(slot_id: int) -> Dictionary
```

- [ ] **Step 1: Write failing tests in `test/test_save_manager.gd`:**
  - Setup and teardown wiping `user://test_saves/`.
  - `test_save_and_load_slot_round_trip`
  - `test_atomic_write_leaves_no_stray_tmp_file`
  - `test_get_slot_summaries_reports_empty_and_populated_slots`
  - `test_load_slot_corrupted_json_returns_null_safely`
  - `test_delete_slot_removes_file_and_updates_summary`
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_save_manager.gd -gexit
  ```

- [ ] **Step 3: Implement `core/save_manager.gd`:**
  - Use `FileAccess` and `DirAccess` with `base_dir`.
  - Atomic write via `.tmp` file and rename.
  - JSON parsing with `JSON.new()`.
  - Summary extraction without loading full world dictionaries.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_save_manager.gd -gexit
  ```

- [ ] **Step 5: Verify core invariants and commit:**

  ```sh
  godot --headless --import
  git add core/save_manager.gd* test/test_save_manager.gd*
  git commit -m "feat: implement SaveManager atomic persistence and slot summaries"
  ```

---

### Task 3: Field State Capture & Map Tile Mutation Rehydration

Extend `FieldMap` to report mutated tiles and `Field` to capture and restore full state.

**Files:**

- Modify: `core/field_map.gd`
- Modify: `scenes/field.gd`
- Modify: `test/test_field_restore.gd`

**Interfaces:**

```gdscript
# In FieldMap:
func get_modified_tiles() -> Dictionary[Vector2i, String]

# In Field:
func capture_state() -> Dictionary
func restore(restore_state: Dictionary) -> void
```

- [ ] **Step 1: Write tests in `test/test_field_restore.gd`:**
  - `test_field_capture_state_returns_coordinates_facing_and_modified_tiles`
  - `test_field_restore_reapplies_modified_tiles_and_refreshes_view`
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_restore.gd -gexit
  ```

- [ ] **Step 3: Implement tile modification tracking and field capture:**
  - In `core/field_map.gd`: Track modified glyphs in `_modified_glyphs: Dictionary[Vector2i, String]` whenever `set_glyph()` is called. Expose `get_modified_tiles()`.
  - In `scenes/field.gd`: Implement `capture_state() -> Dictionary`.
  - In `scenes/field.gd`: Update `restore()` to loop through `modified_tiles` and apply them to `_map`, then refresh `_view`.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_restore.gd -gexit
  ```

- [ ] **Step 5: Verify core invariants and commit:**

  ```sh
  godot --headless --import
  git add core/field_map.gd scenes/field.gd test/test_field_restore.gd
  git commit -m "feat: track tile mutations and implement field state capture"
  ```

---

### Task 4: SaveSlotMenu UI (10-Slot Selector for Save & Load)

Build `SaveSlotMenu` in `ui/save_slot_menu.gd` as a reusable 10-slot selector.

**Files:**

- Create: `ui/save_slot_menu.gd`
- Create: `test/test_save_slot_menu.gd`

**Interfaces:**

```gdscript
class_name SaveSlotMenu
extends CanvasLayer

enum Mode { SAVE, LOAD }

signal slot_selected(slot_id: int, mode: Mode)
signal cancelled

var mode: Mode = Mode.SAVE
var selected_index: int = 0

func setup(summaries: Array[Dictionary], initial_mode: Mode) -> void
func handle_input_action(action: String) -> void
func get_selected_slot_id() -> int
```

- [ ] **Step 1: Write failing tests in `test/test_save_slot_menu.gd`:**
  - `test_setup_populates_10_slots_with_summaries`
  - `test_navigation_up_and_down_wraps_index`
  - `test_load_mode_skips_or_blocks_empty_slots`
  - `test_save_mode_occupied_slot_prompts_confirmation`
  - `test_cancel_action_emits_cancelled_signal`
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_save_slot_menu.gd -gexit
  ```

- [ ] **Step 3: Implement `ui/save_slot_menu.gd`:**
  - Visual panel with Catppuccin styling, listing slots 1..10.
  - Format playtime as `HH:MM:SS`.
  - Handle `ui_up`, `ui_down`, `ui_accept`, `ui_cancel`.
  - Overwrite confirmation state: when selecting occupied slot in `SAVE` mode, show *"Overwrite Slot X? (Yes / No)"*.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_save_slot_menu.gd -gexit
  ```

- [ ] **Step 5: Commit:**

  ```sh
  godot --headless --import
  git add ui/save_slot_menu.gd* test/test_save_slot_menu.gd*
  git commit -m "feat: implement SaveSlotMenu 10-slot selector"
  ```

---

### Task 5: FieldMenu UI (Field Pause System Menu)

Build `FieldMenu` in `ui/field_menu.gd` and wire `ui_cancel` in `Field` to pause and open it.

**Files:**

- Create: `ui/field_menu.gd`
- Modify: `scenes/field.gd`
- Create: `test/test_field_menu.gd`

**Interfaces:**

```gdscript
class_name FieldMenu
extends CanvasLayer

signal save_requested
signal load_requested
signal title_requested
signal resume_requested

var selected_index: int = 0

func handle_input_action(action: String) -> void
```

- [ ] **Step 1: Write failing tests in `test/test_field_menu.gd`:**
  - `test_field_menu_options_and_navigation`
  - `test_field_menu_selection_emits_matching_signals`
  - `test_field_opens_menu_on_ui_cancel_and_freezes_player`
  - `test_field_menu_resume_unfreezes_player`
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_menu.gd -gexit
  ```

- [ ] **Step 3: Implement `ui/field_menu.gd` and field wiring:**
  - Build `FieldMenu` with options: Save, Load, Title, Resume.
  - In `scenes/field.gd`: Check `event.is_action_pressed("ui_cancel")` in `_unhandled_input()`. If dialogue is not open, instantiate `FieldMenu`, freeze player, and connect signals.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_menu.gd -gexit
  ```

- [ ] **Step 5: Commit:**

  ```sh
  godot --headless --import
  git add ui/field_menu.gd* scenes/field.gd test/test_field_menu.gd*
  git commit -m "feat: implement FieldMenu pause menu and field integration"
  ```

---

### Task 6: Title Screen Integration ("Load Game" Option)

Update `TitleMenu` and `Title` to include "Load Game", enabling it when save slots are populated.

**Files:**

- Modify: `ui/title_menu.gd`
- Modify: `scenes/title.gd`
- Modify: `test/test_title_menu.gd`

**Interfaces:**

```gdscript
# In TitleMenu:
signal load_game_requested
var has_saves: bool = false
```

- [ ] **Step 1: Write tests in `test/test_title_menu.gd`:**
  - `test_title_menu_includes_load_game_option`
  - `test_title_menu_load_game_emits_signal_when_active`
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_title_menu.gd -gexit
  ```

- [ ] **Step 3: Update `ui/title_menu.gd` and `scenes/title.gd`:**
  - Insert "Load Game" between "New Game" and "Quick Battle".
  - Wire signal `load_game_requested` through `Title`.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_title_menu.gd -gexit
  ```

- [ ] **Step 5: Commit:**

  ```sh
  git add ui/title_menu.gd scenes/title.gd test/test_title_menu.gd
  git commit -m "feat: add Load Game option to Title screen"
  ```

---

### Task 7: Game Coordinator Integration & End-to-End Save/Load Flow

Connect all components in `Game`, implement playtime tracking, and verify full save and load cycles.

**Files:**

- Modify: `scenes/game.gd`
- Create: `test/test_save_load_game_flow.gd`

**Interfaces:**

```gdscript
# In Game:
var save_manager: SaveManager
var playtime_seconds: float = 0.0

func save_to_slot(slot_id: int) -> bool
func load_from_slot(slot_id: int) -> bool
```

- [ ] **Step 1: Write failing tests in `test/test_save_load_game_flow.gd`:**
  - `test_game_playtime_accumulates_during_field_mode`
  - `test_game_save_to_slot_writes_complete_save_data`
  - `test_game_load_from_slot_restores_world_flags_player_cell_and_tiles`
  - `test_title_screen_load_slot_transitions_to_field`
- [ ] **Step 2: Run test to verify it fails:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_save_load_game_flow.gd -gexit
  ```

- [ ] **Step 3: Implement Game save/load methods and slot overlays:**
  - Add `SaveManager` instance to `Game`.
  - Update `_process(delta)` to accumulate `playtime_seconds` when in `FIELD` or `BATTLE`.
  - Implement `save_to_slot(slot_id)`: gathers `Field.capture_state()`, `world_state.to_dict()`, writes file.
  - Implement `load_from_slot(slot_id)`: reads `SaveData`, fades out, instantiates `Field`, sets `world_state`, calls `field.restore()`, fades in.
  - Wire Title "Load Game" to open `SaveSlotMenu`.
  - Wire Field "Save" and "Load" to open `SaveSlotMenu`.
- [ ] **Step 4: Run test to verify it passes:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_save_load_game_flow.gd -gexit
  ```

- [ ] **Step 5: Commit:**

  ```sh
  godot --headless --import
  git add scenes/game.gd test/test_save_load_game_flow.gd*
  git commit -m "feat: wire Game coordinator save and load flow"
  ```

---

### Task 8: Visual Verification & Handoff Update

Add screenshot probe hooks for `FieldMenu` and `SaveSlotMenu`, verify visual captures, and update `docs/HANDOFF.md`.

**Files:**

- Modify: `scenes/screenshot_probe.gd`
- Modify: `docs/HANDOFF.md`

- [ ] **Step 1: Add probe hooks in `scenes/screenshot_probe.gd`:**
  - `SORTIE_FIELD_MENU`: Opens the field pause menu and captures the screenshot.
  - `SORTIE_SAVE_MENU`: Opens the save slot menu and captures the screenshot.
- [ ] **Step 2: Run visual captures and verify images:**

  ```sh
  SORTIE_SHOT=out.png SORTIE_FIELD_MENU=true godot scenes/game.tscn --quit-after 30
  SORTIE_SHOT=out.png SORTIE_SAVE_MENU=true godot scenes/game.tscn --quit-after 30
  ```

- [ ] **Step 3: Run full test suite across entire project:**

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
  ```

- [ ] **Step 4: Update `docs/HANDOFF.md`:**
  - Update status, test totals, and Sub-project 5 completion table.
  - Add run recipes for the new probe hooks.
- [ ] **Step 5: Verify markdown formatting and commit:**

  ```sh
  npx markdownlint-cli --disable MD013 -- docs/HANDOFF.md
  git add scenes/screenshot_probe.gd docs/HANDOFF.md
  git commit -m "docs: add probe hooks and update HANDOFF.md for Sub-project 5"
  ```
