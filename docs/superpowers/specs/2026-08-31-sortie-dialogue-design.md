# Sortie — Interaction & Dialogue Design Spec

- **Date:** 2026-08-31
- **Status:** Draft, pending user review
- **Engine:** Godot 4.7.2 stable, GDScript
- **Precedes:** `2026-08-30-sortie-field-mode-design.md` built field mode; this builds interaction and dialogue on top of it

## 1. Purpose

Field mode lets the player walk around an ASCII world with collision and camera tracking.
The next requirement for a JRPG story mode is **interaction and dialogue**: the player can face an entity or interactable object, press `ui_accept` (Enter / Space), and enter a dialogue sequence with speaker names, text pages, and branching choices.

**Done means:**
1. The player can walk up to an NPC, face them, press `ui_accept`, and open a dialogue box.
2. The dialogue box appears at the bottom of the screen with a speaker name and body text.
3. Linear pages advance with `ui_accept` or mouse click.
4. Branching choices can be navigated with Up/Down arrows and confirmed with `ui_accept` or clicked.
5. The player and NPCs turn to face each other during interaction.
6. Player movement is frozen while dialogue is active.
7. Dialogue closes on completion and returns control to the player.
8. The entire dialogue state machine and interaction geometry are in `core/` and tested headless.

**Explicit non-goals for this sub-project:**
- Voice acting or sound effects on letter draw (can be added later in audio passes).
- Complex event triggers (step triggers, cutscene camera pans, inventory checks) — these belong to Sub-project 3 (Events & World State).
- Switching scenes to battle mode — belongs to Sub-project 4 (Mode Flow & Battle Handoff).
- Character portraits / busts (text + speaker name plate is the agreed scope).

## 2. Where this sits

Story mode roadmap:

| # | Sub-project | Status | Delivers |
|---|---|---|---|
| 1 | Field mode | Done, PRs #8–#14 | Walkable map, collision, camera |
| **2** | **Interaction & dialogue** | **This spec** | Facing interaction, dialogue box, branching choices |
| 3 | Events and world state | Next | Triggers on step/interact, story flags |
| 4 | Mode flow and battle handoff | Later | Title → field → battle → field restore |
| 5 | Save and load | Later | Persistence |
| 6 | Content | Later | World maps, script, encounters |

## 3. Architecture

Following the project's two-layer architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                           CORE                              │
│                                                             │
│  DialogueChoice (RefCounted)                                │
│    ├── text: String                                         │
│    └── next_id: String                                      │
│                                                             │
│  DialogueNode (RefCounted)                                  │
│    ├── id: String                                           │
│    ├── speaker: String                                      │
│    ├── text: String                                         │
│    ├── choices: Array[DialogueChoice]                       │
│    └── next_id: String (for linear advance)                 │
│                                                             │
│  DialogueTree (RefCounted)                                  │
│    ├── nodes: Dictionary (id -> DialogueNode)               │
│    ├── start_node_id: String                                │
│    └── static from_dict(dict) -> DialogueTree               │
│                                                             │
│  DialogueRunner (RefCounted)                                │
│    ├── tree: DialogueTree                                   │
│    ├── current_node_id: String                              │
│    ├── advance() -> bool                                    │
│    ├── select_choice(index: int) -> bool                    │
│    └── is_finished() -> bool                                │
│                                                             │
│  Interaction (RefCounted)                                   │
│    └── static probe_box(box, facing, reach) -> Rect2       │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                      SCENES & UI                            │
│                                                             │
│  ui/dialogue_box.gd (CanvasLayer / Control)                 │
│    ├── Speaker label + RichTextLabel / Label body           │
│    ├── Choice button container (keyboard & mouse nav)       │
│    └── Emits finished / choice_selected                     │
│                                                             │
│  scenes/field_npc.gd (Node2D)                               │
│    ├── LPC sprite rendering with Facing                     │
│    ├── Collision box registration in FieldMap               │
│    └── Holds DialogueTree                                   │
│                                                             │
│  scenes/field_player.gd & scenes/field.gd                   │
│    └── ui_accept -> Interaction.probe_box() -> find NPC     │
│        -> freeze player -> run dialogue -> unfreeze         │
└─────────────────────────────────────────────────────────────┘
```

Both grep invariants must pass with zero output:

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/     # must be empty
grep -rlE 'randf|randi|randomize' core/ | grep -v real_roll_source  # must be empty
```

### New files

| Path | Responsibility |
|---|---|
| `core/dialogue_choice.gd` | Value type: choice text and destination node ID |
| `core/dialogue_node.gd` | Value type: page data (speaker, text, next ID, choices) |
| `core/dialogue_tree.gd` | Tree container and dictionary serializer / builder |
| `core/dialogue_runner.gd` | State machine: navigation, choices, completion |
| `core/interaction.gd` | Pure geometry: computes the interaction probe box from feet box & facing |
| `ui/dialogue_box.gd` | Presentation: bottom box, speaker name, text rendering, choices |
| `scenes/field_npc.gd` | NPC representation: LPC sprite, facing, interaction target |
| `test/test_dialogue.gd` | Headless tests for dialogue tree, runner, branching, and errors |
| `test/test_interaction.gd` | Headless tests for interaction reach and box geometry |
| `test/test_dialogue_box.gd` | UI tests: display, key navigation, choice selection, signals |
| `test/test_field_interaction.gd` | Integration tests: player facing NPC, pressing accept, dialogue cycle |

### Modified files

| Path | Change |
|---|---|
| `scenes/field_player.gd` | Add `frozen: bool` flag to suspend movement/input during dialogue |
| `scenes/field.gd` | Spawns test NPC(s), hooks player `ui_accept` interaction to dialogue box |
| `scenes/screenshot_probe.gd` | Support `SORTIE_FIELD_INTERACT` for visual capture of dialogue UI |

---

## 4. Core Rules Specification

### 4.1 Dialogue Data Model

A dialogue sequence is a directed graph of `DialogueNode`s identified by string keys.

```gdscript
class_name DialogueChoice
extends RefCounted

var text: String = ""
var next_id: String = ""

func _init(p_text: String = "", p_next_id: String = "") -> void:
	text = p_text
	next_id = p_next_id
```

```gdscript
class_name DialogueNode
extends RefCounted

var id: String = ""
var speaker: String = ""
var text: String = ""
var choices: Array[DialogueChoice] = []
var next_id: String = ""

func has_choices() -> bool:
	return not choices.is_empty()
```

```gdscript
class_name DialogueTree
extends RefCounted

var start_node_id: String = ""
var nodes: Dictionary = {} # String -> DialogueNode

static func from_dict(dict: Dictionary) -> DialogueTree:
	# Parses standard dictionary / JSON structure into DialogueTree
	...
```

Example JSON / Dictionary structure:
```json
{
  "start": "intro",
  "nodes": {
    "intro": {
      "speaker": "Guard",
      "text": "Halt! Who goes there?",
      "choices": [
        { "text": "I am a traveler.", "next": "traveler" },
        { "text": "None of your business.", "next": "rude" }
      ]
    },
    "traveler": {
      "speaker": "Guard",
      "text": "Safe travels, then.",
      "next": ""
    },
    "rude": {
      "speaker": "Guard",
      "text": "Watch your tongue!",
      "next": ""
    }
  }
}
```

### 4.2 Dialogue Runner (`core/dialogue_runner.gd`)

A pure state machine that executes a `DialogueTree`:

- `current_node() -> DialogueNode`: returns the active node, or `null` if finished.
- `advance() -> bool`:
  - If the current node has choices: returns `false` (cannot advance linear path when choices are pending).
  - If `next_id` is empty (`""`): finishes the dialogue and returns `false`.
  - If `next_id` exists: transitions to `next_id` and returns `true`.
  - If `next_id` is invalid: pushes error, finishes, and returns `false`.
- `select_choice(index: int) -> bool`:
  - If current node has no choices or index out of bounds: returns `false`.
  - Otherwise, transitions to choice's `next_id` (or finishes if empty) and returns `true`.
- `is_finished() -> bool`: returns whether dialogue has concluded.

### 4.3 Interaction Geometry (`core/interaction.gd`)

Interaction must feel natural: standing in front of an NPC and facing them must reach them, without requiring pixel-perfect alignment.

Given:
- Player feet box: `Rect2` (size `32x20` at player position + offset)
- Player facing: `Facing.Direction`
- Interaction reach: `REACH := 16.0` px

`Interaction.probe_box(player_box: Rect2, facing: Facing.Direction, reach: float = 16.0) -> Rect2`:
- `Facing.Direction.UP`: `Rect2(player_box.position.x, player_box.position.y - reach, player_box.size.x, reach)`
- `Facing.Direction.DOWN`: `Rect2(player_box.position.x, player_box.end.y, player_box.size.x, reach)`
- `Facing.Direction.LEFT`: `Rect2(player_box.position.x - reach, player_box.position.y, reach, player_box.size.y)`
- `Facing.Direction.RIGHT`: `Rect2(player_box.end.x, player_box.position.y, reach, player_box.size.y)`

An entity is interactable if its collision/interaction bounding box intersects `probe_box`.

---

## 5. UI Presentation (`ui/dialogue_box.gd`)

The dialogue box is a bottom-anchored control:
- **Dimensions & Placement:** Width matching viewport minus margins (e.g. bottom 140px, padded 16px from edges).
- **Styling:** Consistent with `ActionMenu` and `ForecastPanel` (dark semi-transparent background, crisp borders, high-contrast text).
- **Speaker Plate:** Small dedicated label container above/inside the text box for the speaker's name.
- **Body Text:** Clear label rendering dialogue text.
- **Choice List:** When choices are present:
  - Vertical list of buttons or selectable rows.
  - Keyboard navigation: `ui_up` / `ui_down` moves selection indicator.
  - `ui_accept` or mouse click triggers selection.
- **Advancement indicator:** A subtle blinking arrow or indicator when waiting for `ui_accept` to advance linear text.

---

## 6. NPC Scene (`scenes/field_npc.gd`)

- Inherits `Node2D`.
- Renders an LPC walk sheet (idle frame 0 by default, row selected by `facing`).
- Properties:
  - `npc_name: String`
  - `dialogue: DialogueTree`
  - `facing: Facing.Direction`
- Collision:
  - Registers its feet box in `FieldMap` or field collision list so the player cannot walk through the NPC.
- When interacted with:
  - Sets its facing toward the player: `Facing.toward(player.position - position)` (or `Facing.from_motion(player.position - position, facing)`).

---

## 7. Verification Strategy

1. **Unit tests for `core/` (Headless):**
   - `test_dialogue.gd`: verifies tree construction, node transitions, invalid IDs, choice selection, empty next finishes, and branching graphs.
   - `test_interaction.gd`: verifies probe boxes in all 4 cardinal directions and overlap checks against target bounding boxes.
2. **UI & View tests (`test/test_dialogue_box.gd`, `test/test_input.gd` style):**
   - Synthesizes `InputEventKey` (`ui_accept`, `ui_up`, `ui_down`) and verifies text advancement and choice selection.
3. **Integration tests (`test/test_field_interaction.gd`):**
   - Spawns player and NPC on a test map.
   - Player moves adjacent, faces NPC, presses `ui_accept`.
   - Asserts player freezes, dialogue box appears with correct speaker/text, NPC turns to face player.
   - Advances dialogue to end; asserts player unfreezes.
4. **Visual verification:**
   - Extend `scenes/screenshot_probe.gd` with `SORTIE_FIELD_INTERACT` to capture dialogue box rendering with text and choices.

---

## 8. Summary of Tasks for Implementation Plan

1. **Core Dialogue Data & Runner:** `DialogueChoice`, `DialogueNode`, `DialogueTree`, `DialogueRunner` + `test_dialogue.gd`.
2. **Core Interaction Geometry:** `Interaction.probe_box()` + `test_interaction.gd`.
3. **Dialogue Box UI:** `ui/dialogue_box.gd` + `test_dialogue_box.gd`.
4. **Field NPC Scene:** `scenes/field_npc.gd` + LPC sprite rendering & collision.
5. **Field Interaction Wiring:** `scenes/field_player.gd` (freezing) and `scenes/field.gd` (interact event handling) + `test_field_interaction.gd`.
6. **Screenshot Verification & Handoff Update:** Capture dialogue box in action and update docs.
