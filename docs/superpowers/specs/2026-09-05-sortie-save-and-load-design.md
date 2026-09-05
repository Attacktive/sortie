# Sortie — Save & Load Design Spec

- **Date:** 2026-09-05
- **Status:** Draft, pending user review
- **Engine:** Godot 4.7.2 stable, GDScript
- **Precedes:** `2026-09-05-sortie-mode-flow-design.md` unified Title, Field, and Battle modes; this adds disk persistence and slot management

## 1. Purpose

With Sub-project 4 complete, Sortie runs as a cohesive vertical slice from Title screen to Field exploration and Battle handoff. However, all progression (`WorldState` flags, player coordinates, dynamically mutated tiles) is ephemeral and lost when the application quits or returns to the Title screen.

Sub-project 5 implements **Save & Load**, providing durable disk persistence across 10 save slots:

1. **Pure Domain Data Schema (`SaveData`)**: Pure `RefCounted` container in `core/` representing a serialized save snapshot (version, timestamp, playtime, location, world flags, player field state, and mutated tiles) with validation and round-trip conversion.
2. **Atomic Disk Persistence (`SaveManager`)**: Service managing `user://saves/slot_<id>.json` files using atomic `.tmp` writes to eliminate write-corruption risks, providing lightweight slot summary inspection without full world loading.
3. **Field System / Pause Menu (`FieldMenu`)**: Pause overlay opened with `ui_cancel` (Escape) during field exploration, offering "Save", "Load", "Title", and "Resume".
4. **Reusable 10-Slot Selector (`SaveSlotMenu`)**: Keyboard-navigable UI supporting both saving (overwriting slots with confirmation) and loading (selecting occupied slots).
5. **Title Screen Integration**: Title menu updated with "Load Game" (navigable when save files exist across any of the 10 slots).
6. **Game Coordination & State Rehydration**: `Game` coordinates saving snapshots, loading slots, executing screen transitions, and restoring exact player coordinates, facing, camera boundaries, and map tile alterations.

**Done means:**

- Pressing `ui_cancel` on the field opens the Field System Menu, freezing player movement.
- Selecting "Save" opens the 10-slot selector; choosing a slot writes an atomic JSON save file to disk with timestamp, location, playtime, world flags, and field state.
- Selecting "Load" from either the Field Menu or Title Screen presents occupied slots and rehydrates the saved world state, player position, facing, and tile modifications.
- Corrupted or invalid save files fail gracefully without crashing or corrupting adjacent slots.
- All headless GUT tests pass (including I/O tests directed to an isolated test directory).
- Core two-layer architecture is strictly preserved (`core/save_data.gd` remains pure domain `RefCounted` with zero Node or scene-tree dependencies).

**Explicit non-goals for this sub-project:**

- Cloud sync or cross-device save synchronization.
- Multiple separate campaign/profile directories (10 numbered slots in `user://saves/` are sufficient for the vertical slice).
- Mid-battle combat state saving (battles are short tactical encounters; saves occur on the field).
- Party management or inventory screen (Sub-project 6).

---

## 2. Where this sits

Story mode roadmap:

| # | Sub-project | Status | Delivers |
| --- | --- | --- | --- |
| 1 | Field mode | Done, PRs #8–#14 | Walkable map, collision, camera |
| 2 | Interaction & dialogue | Done, PR #16 | Facing interaction, dialogue box, branching choices |
| 3 | Events & world state | Done, PRs #17, #24, #26 | Step/interact triggers, world flags, conditional choices, tile mutation |
| 4 | Mode flow & battle handoff | Done, PR #28 | Title $\leftrightarrow$ Field $\leftrightarrow$ Battle lifecycle, transitions, defeat flow |
| **5** | **Save & load** | **This spec** | Disk persistence of WorldState, field snapshots, 10-slot management |
| 6 | Content | Later | World maps, intro story script, boss encounter, victory fanfare |

---

## 3. Architecture

Following the project's two-layer architecture, data contracts stay decoupled in `core/` while disk I/O and UI components coordinate in `ui/` and `scenes/`:

```text
┌─────────────────────────────────────────────────────────────┐
│                            CORE                             │
│                                                             │
│  core/save_data.gd (RefCounted)                             │
│    ├── Schema versioning & validation                       │
│    ├── Metadata (slot_id, timestamp, playtime, location)    │
│    ├── world_state: Dictionary (WorldState snapshot)        │
│    └── field_state: Dictionary (cell, facing, mutated tiles) │
│                                                             │
│  core/save_manager.gd (RefCounted / Service)                │
│    ├── Atomic disk I/O (user://saves/slot_XX.json)          │
│    ├── Slot discovery & lightweight header summaries        │
│    └── Base directory configuration (for isolated tests)    │
└─────────────────────────────────────────────────────────────┘
                               ▲
                               │
┌──────────────────────────────┴──────────────────────────────┐
│                         PRESENTATION                        │
│                                                             │
│  scenes/game.gd (Root coordinator)                          │
│    ├── Tracks cumulative playtime_seconds                   │
│    ├── Serializes active Field & WorldState into SaveData   │
│    └── Rehydrates WorldState & calls Field.restore()        │
│                                                             │
│  ui/field_menu.gd (Field pause menu: Save, Load, Title)     │
│  ui/save_slot_menu.gd (10-slot selector for Save & Load)    │
│  ui/title_menu.gd (Includes "Load Game" option)             │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Components & Contracts

### 4.1. Core Data Contract (`core/save_data.gd`)

Pure `RefCounted` data model representing a single save file:

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

func to_dict() -> Dictionary:
    return {
        "version": version,
        "slot_id": slot_id,
        "timestamp": timestamp,
        "playtime_seconds": playtime_seconds,
        "location_name": location_name,
        "party_leader": party_leader,
        "world_state": world_state_data.duplicate(true),
        "field_state": field_state_data.duplicate(true),
    }

static func from_dict(dict: Dictionary) -> SaveData:
    if not validate_dict(dict):
        return null
    var data := SaveData.new()
    data.version = int(dict.get("version", 0))
    data.slot_id = int(dict.get("slot_id", 1))
    data.timestamp = str(dict.get("timestamp", ""))
    data.playtime_seconds = float(dict.get("playtime_seconds", 0.0))
    data.location_name = str(dict.get("location_name", "Unknown"))
    data.party_leader = str(dict.get("party_leader", ""))
    data.world_state_data = dict.get("world_state", {}).duplicate(true)
    data.field_state_data = dict.get("field_state", {}).duplicate(true)
    return data

static func validate_dict(dict: Dictionary) -> bool:
    if not dict.has("version") or int(dict["version"]) <= 0:
        return false
    if not dict.has("slot_id") or int(dict["slot_id"]) < 1 or int(dict["slot_id"]) > 10:
        return false
    if not dict.has("world_state") or not (dict["world_state"] is Dictionary):
        return false
    if not dict.has("field_state") or not (dict["field_state"] is Dictionary):
        return false
    return true
```

### 4.2. Disk Persistence (`core/save_manager.gd`)

Handles file creation, deletion, atomic writing, and fast summary scanning:

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

func get_slot_path(slot_id: int) -> String:
    return "%s/slot_%02d.json" % [base_dir, slot_id]

func save_slot(data: SaveData) -> Result:
    if data.slot_id < 1 or data.slot_id > MAX_SLOTS:
        return Result.ERR_INVALID_SLOT

    DirAccess.make_dir_recursive_absolute(base_dir)
    var final_path := get_slot_path(data.slot_id)
    var tmp_path := final_path + ".tmp"

    var file := FileAccess.open(tmp_path, FileAccess.WRITE)
    if file == null:
        return Result.ERR_FILE_WRITE

    var json_string := JSON.stringify(data.to_dict(), "\t")
    file.store_string(json_string)
    file.close()

    var err := DirAccess.rename_absolute(tmp_path, final_path)
    if err != OK:
        return Result.ERR_FILE_WRITE

    return Result.OK

func load_slot(slot_id: int) -> SaveData:
    if slot_id < 1 or slot_id > MAX_SLOTS:
        return null

    var path := get_slot_path(slot_id)
    if not FileAccess.file_exists(path):
        return null

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null

    var content := file.get_as_text()
    file.close()

    var json := JSON.new()
    if json.parse(content) != OK or not (json.data is Dictionary):
        return null

    return SaveData.from_dict(json.data)

func get_slot_summaries() -> Array[Dictionary]:
    var summaries: Array[Dictionary] = []
    for id in range(1, MAX_SLOTS + 1):
        summaries.append(get_slot_summary(id))
    return summaries

func get_slot_summary(slot_id: int) -> Dictionary:
    var summary := {
        "slot_id": slot_id,
        "is_empty": true,
        "timestamp": "",
        "playtime_seconds": 0.0,
        "location_name": "",
        "party_leader": "",
    }
    var path := get_slot_path(slot_id)
    if not FileAccess.file_exists(path):
        return summary

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return summary

    var content := file.get_as_text()
    file.close()

    var json := JSON.new()
    if json.parse(content) == OK and json.data is Dictionary:
        var d: Dictionary = json.data
        summary["is_empty"] = false
        summary["timestamp"] = d.get("timestamp", "")
        summary["playtime_seconds"] = d.get("playtime_seconds", 0.0)
        summary["location_name"] = d.get("location_name", "Unknown")
        summary["party_leader"] = d.get("party_leader", "")

    return summary
```

### 4.3. UI Presentation

#### Field Menu (`ui/field_menu.gd`)

- Subclasses `CanvasLayer`.
- Centered modal dialog styling matching `DialogueBox` / Catppuccin palette.
- List items:
  - **Save**: Emits `save_requested`.
  - **Load**: Emits `load_requested` (disabled if all slots are empty).
  - **Title**: Emits `title_requested`.
  - **Resume**: Emits `closed`.
- Keyboard navigation with Up/Down and Enter (`ui_accept`) / Escape (`ui_cancel`).

#### Save Slot Menu (`ui/save_slot_menu.gd`)

- Displays slots 1 through 10 in a vertical list with cursor selection.
- Operates in `Mode.SAVE` or `Mode.LOAD`.
- In `Mode.SAVE`, selecting an occupied slot displays an inline confirmation: *"Overwrite Slot X? (Yes / No)"*.
- In `Mode.LOAD`, empty slots cannot be activated.
- Formats playtime as `HH:MM:SS` (e.g. `00:14:32`).

#### Title Menu (`ui/title_menu.gd`)

- Updated items:
  1. **New Game**
  2. **Load Game** (disabled when no saves exist)
  3. **Quick Battle**
  4. **Quit**

---

## 5. Game Coordination & State Restoration

### 5.1. Playtime Tracking

In `scenes/game.gd`:

- `var playtime_seconds: float = 0.0`
- Updated in `_process(delta)` when `current_mode == Mode.FIELD or current_mode == Mode.BATTLE`.

### 5.2. Field State Capture & Restore

In `scenes/field.gd`:

- **`capture_state() -> Dictionary`**:

  ```gdscript
  func capture_state() -> Dictionary:
      var modified_tiles := {}
      if _map != null:
          modified_tiles = _map.get_modified_tiles()
      return {
          "cell": GridGeometry.position_to_cell(_player.position),
          "facing": _player.facing,
          "modified_tiles": modified_tiles,
      }
  ```

- **`restore(restore_state: Dictionary) -> void`**:
  - Sets player cell and facing.
  - Updates camera limits and resets smoothing.
  - Iterates `restore_state.get("modified_tiles", {})` to update `_map.set_glyph(cell, glyph)` and refreshes `_view`.
  - Refreshes NPC dialogues based on `world_state`.

### 5.3. Saving & Loading Lifecycle in `scenes/game.gd`

```text
Field Exploration (Player presses Escape)
   │
   ▼
FieldMenu pops up (Player movement frozen)
   │
   ├─► Selects "Save"
   │     │
   │     ▼
   │   SaveSlotMenu opens in SAVE mode
   │     │ (Player chooses Slot 1)
   │     ▼
   │   Game captures SaveData:
   │     - timestamp = Time.get_datetime_string_from_system()
   │     - playtime_seconds = Game.playtime_seconds
   │     - world_state = Game.world_state.to_dict()
   │     - field_state = Field.capture_state()
   │   SaveManager writes to user://saves/slot_01.json
   │   SaveSlotMenu refreshes summary & returns to FieldMenu
   │
   └─► Selects "Load"
         │
         ▼
       SaveSlotMenu opens in LOAD mode
         │ (Player chooses Slot 1)
         ▼
       Game initiates TransitionLayer fade out:
         - Reads SaveData via SaveManager.load_slot(1)
         - Restores Game.playtime_seconds
         - Game.world_state = WorldState.from_dict(save_data.world_state)
         - Switches scene to new Field instance
         - Calls Field.restore(save_data.field_state)
         - TransitionLayer fades in
         - Field exploration resumes
```

---

## 6. Verification & Test Strategy

### 6.1. Unit Tests

- `test/test_save_data.gd`:
  - Validates `SaveData.to_dict()` and `from_dict()` round-trip fidelity.
  - Verifies rejection of missing keys, invalid versions, or non-numeric slot IDs.
- `test/test_save_manager.gd`:
  - Uses `user://test_saves/` sandbox directory.
  - Tests atomic writes, `.tmp` cleanup, corrupted JSON recovery, and slot summaries for both empty and populated slots.
  - Cleans up the test directory in teardown.

### 6.2. UI & Navigation Tests

- `test/test_field_menu.gd`:
  - Tests menu opening on `ui_cancel`, list focus, option signal emissions, and player freeze.
- `test/test_save_slot_menu.gd`:
  - Tests keyboard cursor wrapping, empty slot blocking in Load mode, and overwrite confirmation prompt.

### 6.3. End-to-End Game Flow Tests

- `test/test_save_load_game_flow.gd`:
  - Starts game, walks player to cell (6, 3), modifies a world flag and a field tile.
  - Calls `game.save_to_slot(1)`.
  - Boots a new `Game` instance, calls `game.load_from_slot(1)`.
  - Asserts exact player position, facing, world flag value, and modified tile glyph.

### 6.4. Visual Verification

- Add probe hooks:
  - `SORTIE_FIELD_MENU`: Captures screenshot of open FieldMenu over the field.
  - `SORTIE_SAVE_MENU`: Captures screenshot of SaveSlotMenu displaying populated and empty slots.
