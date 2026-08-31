# Sortie — Events & World State Design Spec

- **Date:** 2026-08-31
- **Status:** Draft, pending user review
- **Engine:** Godot 4.7.2 stable, GDScript
- **Precedes:** `2026-08-31-sortie-dialogue-design.md` built interaction and dialogue; this builds world state flags, triggers, and events on top of it

## 1. Purpose

With field movement (Sub-project 1) and NPC dialogue (Sub-project 2) working, the game world needs persistence, cause-and-effect triggers, and conditional reactions.
Sub-project 3 introduces **Events & World State**:
1. **World State**: Key-value state tracking (boolean story flags, numerical counters, strings, and sets) that can be serialized/deserialized for save/load.
2. **Conditions**: Boolean logic evaluating world state (`==`, `!=`, `<`, `<=`, `>`, `>=`).
3. **Triggers**: Step triggers (walking onto a cell) and interaction triggers (interacting with chests, doors, signs, levers, switches).
4. **Event Actions**: Atomic state changes (setting flags, triggering dialogue, modifying map tiles).
5. **Conditional Dialogue**: NPCs switching dialogue based on world state, and dialogue choices gated by conditions.

**Done means:**
1. Stepping on a designated tile triggers a configured event (e.g. greeting cutscene, one-shot gate close).
2. Interacting with map props (e.g. a chest `'C'`) triggers actions (sets flag, displays message, and visually opens the chest to `'O'`).
3. NPCs dynamically select dialogue based on world state flags (first talk vs. quest completed).
4. Dialogue choices can be gated by world state conditions (e.g. requiring a flag or item).
5. The entire state engine, condition evaluator, and trigger system live in `core/` and are verified headless.

**Explicit non-goals for this sub-project:**
- Full disk save/load file I/O (belongs to Sub-project 5, though `WorldState.to_dict()` and `from_dict()` provide the data contract).
- Scene switching to battle mode (belongs to Sub-project 4).
- Complex cutscene camera director sequences (simple pan/lock is sufficient).

## 2. Where this sits

Story mode roadmap:

| # | Sub-project | Status | Delivers |
|---|---|---|---|
| 1 | Field mode | Done, PRs #8–#14 | Walkable map, collision, camera |
| 2 | Interaction & dialogue | Done, PR #16 | Facing interaction, dialogue box, branching choices |
| **3** | **Events & world state** | **This spec** | Step/interact triggers, world flags, conditional dialogue, tile mutation |
| 4 | Mode flow & battle handoff | Next | Title → field → battle → field restore |
| 5 | Save & load | Later | Disk persistence of WorldState and roster |
| 6 | Content | Later | World maps, story script, encounters |

## 3. Architecture

Following the project's two-layer architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                           CORE                              │
│                                                             │
│  WorldState (RefCounted)                                    │
│    ├── _flags: Dictionary (String -> Variant)               │
│    ├── get_flag(key, default) -> Variant                    │
│    ├── set_flag(key, value)                                 │
│    ├── has_flag(key) -> bool                                │
│    ├── evaluate(condition: EventCondition) -> bool         │
│    ├── to_dict() -> Dictionary                              │
│    └── static from_dict(dict) -> WorldState                 │
│                                                             │
│  EventCondition (RefCounted)                                │
│    ├── key: String, op: Operator, target_value: Variant    │
│    ├── evaluate(state: WorldState) -> bool                  │
│    └── static eq(), is_true(), is_false(), gte(), etc.      │
│                                                             │
│  EventAction (RefCounted)                                   │
│    ├── type: ActionType (SET_FLAG, DIALOGUE, MODIFY_TILE)   │
│    └── params: Dictionary                                   │
│                                                             │
│  EventTrigger (RefCounted)                                  │
│    ├── type: TriggerType (STEP, INTERACT)                   │
│    ├── cell: Vector2i                                       │
│    ├── condition: EventCondition                            │
│    ├── actions: Array[EventAction]                          │
│    ├── once: bool, fired: bool                              │
│    └── can_fire(state: WorldState) -> bool                  │
│                                                             │
│  TriggerRegistry (RefCounted)                               │
│    ├── triggers: Array[EventTrigger]                        │
│    ├── triggers_at(cell, type) -> Array[EventTrigger]       │
│    └── static from_dict(dict) -> TriggerRegistry            │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                      SCENES & UI                            │
│                                                             │
│  scenes/field.gd                                            │
│    ├── Owns WorldState & TriggerRegistry                    │
│    ├── Cell tracking on player step -> fires STEP triggers  │
│    ├── Interaction check -> fires INTERACT triggers on tiles│
│    └── Handles MODIFY_TILE actions (updates FieldMap & View)│
│                                                             │
│  scenes/field_npc.gd                                        │
│    └── Evaluates conditional dialogue trees on interaction  │
│                                                             │
│  core/dialogue_choice.gd                                    │
│    └── Optional condition check before displaying choice    │
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
| `core/world_state.gd` | Key-value state storage, serialization, flag queries |
| `core/event_condition.gd` | Comparison operators and boolean evaluation over `WorldState` |
| `core/event_action.gd` | Action descriptors: `SET_FLAG`, `SHOW_DIALOGUE`, `MODIFY_TILE` |
| `core/event_trigger.gd` | Spatial trigger definition (`STEP` vs `INTERACT`), condition guard, one-shot flag |
| `core/trigger_registry.gd` | Spatial index of triggers by cell and event type |
| `test/test_world_state.gd` | Headless tests for flag storage, conditions, and serialization |
| `test/test_triggers.gd` | Headless tests for trigger matching, conditions, and one-shot logic |
| `test/test_conditional_dialogue.gd` | Headless tests for condition-gated dialogue choices and NPC tree selection |
| `test/test_field_events.gd` | Integration tests for step triggers, chest interaction, and tile modification |

### Modified files

| Path | Change |
|---|---|
| `core/field_map.gd` | Add `set_glyph(cell: Vector2i, glyph: String)` to support dynamic tile modification |
| `core/dialogue_choice.gd` | Add optional `condition: EventCondition` field |
| `core/dialogue_node.gd` / `dialogue_runner.gd` | Filter or evaluate conditional choices |
| `scenes/field_view.gd` | Support redrawing modified map tiles on notification |
| `scenes/field_npc.gd` | Support array of conditional dialogue trees evaluated against `WorldState` |
| `scenes/field.gd` | Initialize `WorldState`, monitor player cell steps, and execute trigger actions |

---

## 4. Core Rules Specification

### 4.1 World State (`core/world_state.gd`)

```gdscript
class_name WorldState
extends RefCounted

## Key-value story state container supporting boolean flags, integer counts, and string states.

var _flags: Dictionary = {}

func set_flag(key: String, value: Variant) -> void:
	_flags[key] = value

func get_flag(key: String, default_value: Variant = null) -> Variant:
	return _flags.get(key, default_value)

func has_flag(key: String) -> bool:
	return _flags.has(key)

func clear() -> void:
	_flags.clear()

func to_dict() -> Dictionary:
	return _flags.duplicate(true)

static func from_dict(dict: Dictionary) -> WorldState:
	var state := WorldState.new()
	state._flags = dict.duplicate(true)
	return state
```

### 4.2 Event Condition (`core/event_condition.gd`)

```gdscript
class_name EventCondition
extends RefCounted

## Evaluates a comparison against a WorldState.

enum Op { EQUAL, NOT_EQUAL, LESS_THAN, LESS_EQUAL, GREATER_THAN, GREATER_EQUAL }

var key: String = ""
var op: Op = Op.EQUAL
var target_value: Variant = null

func _init(p_key: String = "", p_op: Op = Op.EQUAL, p_val: Variant = null) -> void:
	key = p_key
	op = p_op
	target_value = p_val

func evaluate(state: WorldState) -> bool:
	if state == null:
		return false

	var val = state.get_flag(key)
	match op:
		Op.EQUAL:
			return val == target_value
		Op.NOT_EQUAL:
			return val != target_value
		Op.LESS_THAN:
			return val != null and val < target_value
		Op.LESS_EQUAL:
			return val != null and val <= target_value
		Op.GREATER_THAN:
			return val != null and val > target_value
		Op.GREATER_EQUAL:
			return val != null and val >= target_value
	return false

static func is_true(flag_key: String) -> EventCondition:
	return EventCondition.new(flag_key, Op.EQUAL, true)

static func is_false(flag_key: String) -> EventCondition:
	return EventCondition.new(flag_key, Op.EQUAL, false)

static func eq(flag_key: String, val: Variant) -> EventCondition:
	return EventCondition.new(flag_key, Op.EQUAL, val)

static func gte(flag_key: String, val: Variant) -> EventCondition:
	return EventCondition.new(flag_key, Op.GREATER_EQUAL, val)
```

### 4.3 Event Actions (`core/event_action.gd`)

```gdscript
class_name EventAction
extends RefCounted

## An atomic mutation triggered by an event.

enum Type { SET_FLAG, SHOW_DIALOGUE, MODIFY_TILE }

var type: Type
var params: Dictionary = {}

func _init(p_type: Type, p_params: Dictionary = {}) -> void:
	type = p_type
	params = p_params

static func set_flag(key: String, value: Variant) -> EventAction:
	return EventAction.new(Type.SET_FLAG, { "key": key, "value": value })

static func show_dialogue(tree: DialogueTree) -> EventAction:
	return EventAction.new(Type.SHOW_DIALOGUE, { "dialogue": tree })

static func modify_tile(cell: Vector2i, new_glyph: String) -> EventAction:
	return EventAction.new(Type.MODIFY_TILE, { "cell": cell, "glyph": new_glyph })
```

### 4.4 Event Trigger & Registry (`core/event_trigger.gd` & `core/trigger_registry.gd`)

```gdscript
class_name EventTrigger
extends RefCounted

## A trigger listening for player movement or interaction at a specific cell.

enum TriggerType { STEP, INTERACT }

var type: TriggerType = TriggerType.STEP
var cell: Vector2i = Vector2i.ZERO
var condition: EventCondition = null
var actions: Array[EventAction] = []
var once: bool = false
var fired: bool = false

func can_fire(state: WorldState) -> bool:
	if once and fired:
		return false

	if condition != null and not condition.evaluate(state):
		return false

	return true
```

`TriggerRegistry` indexes triggers by cell for fast lookups during player movement or interaction.

---

## 5. Map & Dialogue Integration

### 5.1 Dynamic Map Mutation (`core/field_map.gd`)

`FieldMap` gains:
```gdscript
func set_glyph(cell: Vector2i, glyph: String) -> void:
	if is_in_bounds(cell):
		_rows[cell.y] = _rows[cell.y].substr(0, cell.x) + glyph + _rows[cell.y].substr(cell.x + 1)
		_solid[cell] = glyph in SOLID_GLYPHS
```
And emits / notifies `FieldView` to redraw the updated tile.

### 5.2 Conditional NPC Dialogue (`scenes/field_npc.gd`)

`FieldNpc` can be configured with an array of conditional dialogue trees:
```gdscript
## Array of Dictionary entries: { "condition": EventCondition, "dialogue": DialogueTree }
var conditional_dialogues: Array[Dictionary] = []

func get_dialogue_for_state(state: WorldState) -> DialogueTree:
	for entry in conditional_dialogues:
		var cond: EventCondition = entry.get("condition")
		if cond == null or cond.evaluate(state):
			return entry.get("dialogue")

	return dialogue
```

### 5.3 Conditional Dialogue Choices (`core/dialogue_choice.gd`)

`DialogueChoice` gains an optional `condition: EventCondition = null`.
When `DialogueNode.get_available_choices(state: WorldState)` is called (or in `DialogueRunner`), choices with failing conditions are filtered out from display.

---

## 6. Verification Strategy

1. **Unit tests in `core/` (Headless):**
   - `test_world_state.gd`: tests `set_flag`, `get_flag`, `has_flag`, `to_dict()`, `from_dict()`, and all `EventCondition` comparison operators.
   - `test_triggers.gd`: tests trigger registration, spatial matching (`STEP` and `INTERACT`), condition filtering, and `once: true` exhaustion.
   - `test_conditional_dialogue.gd`: tests NPC conditional dialogue tree selection and choice gating against `WorldState`.
2. **Integration tests (`test/test_field_events.gd`):**
   - Player steps onto a cell $\rightarrow$ STEP trigger fires, sets flag, shows dialogue, and marks trigger fired.
   - Player faces a chest tile `'C'`, presses `ui_accept` $\rightarrow$ INTERACT trigger fires, modifies tile to `'O'`, sets chest opened flag.
3. **Visual verification:**
   - Extend `screenshot_probe.gd` with `SORTIE_FIELD_TRIGGER=step` or `chest` to verify tile opening and event execution in running scenes.

---

## 7. Summary of Tasks for Implementation Plan

1. **World State & Condition Evaluator:** `core/world_state.gd`, `core/event_condition.gd` + `test/test_world_state.gd`.
2. **Event Actions & Trigger Registry:** `core/event_action.gd`, `core/event_trigger.gd`, `core/trigger_registry.gd` + `test/test_triggers.gd`.
3. **Conditional Dialogue Support:** Choice conditions in `core/dialogue_choice.gd` and conditional NPC trees in `scenes/field_npc.gd` + `test/test_conditional_dialogue.gd`.
4. **Dynamic Map Tile Modification:** `core/field_map.gd` `set_glyph()` and `scenes/field_view.gd` cache refresh.
5. **Field Trigger & Event Wiring:** Player step tracking and tile interaction in `scenes/field.gd` + `test/test_field_events.gd`.
6. **Visual Probe & Handoff Docs:** Screenshot probe event test and update `docs/HANDOFF.md`.
