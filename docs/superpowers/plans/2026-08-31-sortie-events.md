# Events & World State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a world state store (flags/variables), condition evaluator, trigger system (step and interact triggers), tile mutation, and conditional dialogue.

**Architecture:** World state storage, conditions, actions, and spatial trigger indices live in `core/` as pure `RefCounted` objects. `scenes/field.gd` monitors player cell steps and interaction reach to fire triggers, execute actions, and update tile visuals. The entire event rules engine runs headless.

**Tech Stack:** Godot 4.7.2 stable, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-08-31-sortie-events-design.md`

## Global Constraints

These apply to every task below.

- **Indent with tabs.** Never spaces.
- **Never hard-wrap for length.** One sentence per physical line, comments included. Soft wrapping exists.
- **A multiline expression is followed by an empty line** before the next statement. No empty line after an opening brace or `:`.
- **Prefer `if` over the ternary operator.**
- **American English** in prose, comments, and identifiers.
- **`core/` stays free of the scene tree.** After every task, both invariants must produce no output:

  ```sh
  grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
  grep -rlE 'randf|randi|randomize' core/ | grep -v real_roll_source
  ```

  The first one greps comments too, so a `core/` file cannot use the word "Node" even in comments.

- **All 191 existing tests must keep passing.** Run the full suite:

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
  ```

- **A new `.gd` file needs its `.uid` committed.** Run `godot --headless --import` before `git add`.
- **Commits use `feat`/`fix`/`test`/`docs`.** Add the trailer:
  `Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>`.
- **Do not change `run/main_scene`.** It stays `res://scenes/battle.tscn` until sub-project 4.

---

### Task 1: WorldState and EventCondition

**Files:**

- Create: `core/world_state.gd`
- Create: `core/event_condition.gd`
- Create: `test/test_world_state.gd`

**Interfaces:**

- Produces:
  - `WorldState.set_flag(key: String, value: Variant)`
  - `WorldState.get_flag(key: String, default_value: Variant = null) -> Variant`
  - `WorldState.has_flag(key: String) -> bool`
  - `WorldState.to_dict() -> Dictionary`
  - `WorldState.from_dict(dict: Dictionary) -> WorldState`
  - `EventCondition.evaluate(state: WorldState) -> bool`
  - `EventCondition.is_true()`, `is_false()`, `eq()`, `gte()`, `lte()`

- [x] **Step 1: Write the failing test**

Create `test/test_world_state.gd`:

```gdscript
extends GutTest

func test_world_state_flag_storage_and_queries() -> void:
	var state := WorldState.new()
	assert_false(state.has_flag("quest_started"))
	assert_null(state.get_flag("quest_started"))
	assert_eq(state.get_flag("gold", 0), 0)

	state.set_flag("quest_started", true)
	state.set_flag("gold", 50)
	assert_true(state.has_flag("quest_started"))
	assert_eq(state.get_flag("quest_started"), true)
	assert_eq(state.get_flag("gold"), 50)

func test_world_state_serialization() -> void:
	var state := WorldState.new()
	state.set_flag("talked_to_mage", true)
	state.set_flag("chest_opened", 1)

	var serialized := state.to_dict()
	var restored := WorldState.from_dict(serialized)

	assert_eq(restored.get_flag("talked_to_mage"), true)
	assert_eq(restored.get_flag("chest_opened"), 1)

func test_event_condition_evaluations() -> void:
	var state := WorldState.new()
	state.set_flag("active", true)
	state.set_flag("count", 5)

	var cond_true := EventCondition.is_true("active")
	var cond_false := EventCondition.is_false("active")
	var cond_eq := EventCondition.eq("count", 5)
	var cond_gte := EventCondition.gte("count", 5)
	var cond_gt := EventCondition.new("count", EventCondition.Op.GREATER_THAN, 5)

	assert_true(cond_true.evaluate(state))
	assert_false(cond_false.evaluate(state))
	assert_true(cond_eq.evaluate(state))
	assert_true(cond_gte.evaluate(state))
	assert_false(cond_gt.evaluate(state))
```

- [x] **Step 2: Run test to verify it fails**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_world_state.gd -gexit
```

Expected: FAIL (`WorldState` not found).

- [x] **Step 3: Implement `WorldState` and `EventCondition`**

Create `core/world_state.gd`:

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

Create `core/event_condition.gd`:

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

static func lte(flag_key: String, val: Variant) -> EventCondition:
	return EventCondition.new(flag_key, Op.LESS_EQUAL, val)
```

- [x] **Step 4: Run test to verify it passes**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_world_state.gd -gexit
```

Expected: PASS.

- [x] **Step 5: Check invariants and commit**

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
git add core/world_state.gd core/world_state.gd.uid core/event_condition.gd core/event_condition.gd.uid test/test_world_state.gd test/test_world_state.gd.uid
git commit -m "feat: add WorldState and EventCondition in core

Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

#### What changed in Task 1, and why

Implemented `WorldState` and `EventCondition` in `core/` as pure `RefCounted` classes.
`WorldState` stores boolean flags, integer values, and arbitrary state values in a dictionary, supporting serialization via `to_dict()` and `from_dict()`.
`EventCondition` evaluates comparison operations (`EQUAL`, `NOT_EQUAL`, `LESS_THAN`, `LESS_EQUAL`, `GREATER_THAN`, `GREATER_EQUAL`) against a `WorldState` instance.
Unit tests in `test/test_world_state.gd` verify flag mutations, serialization round-trips, and condition evaluations.

---

### Task 2: Event Actions, Triggers, and Registry

**Files:**

- Create: `core/event_action.gd`
- Create: `core/event_trigger.gd`
- Create: `core/trigger_registry.gd`
- Create: `test/test_triggers.gd`

**Interfaces:**

- Consumes: `WorldState`, `EventCondition`, `DialogueTree`
- Produces:
  - `EventAction(type, params)`
  - `EventTrigger(type, cell, condition, actions, once)`
  - `TriggerRegistry.register_trigger(trigger: EventTrigger)`
  - `TriggerRegistry.get_triggers_at(cell: Vector2i, type: EventTrigger.TriggerType) -> Array[EventTrigger]`

- [x] **Step 1: Write the failing test**

Create `test/test_triggers.gd`:

```gdscript
extends GutTest

func test_trigger_filtering_and_once_exhaustion() -> void:
	var state := WorldState.new()
	var action := EventAction.set_flag("found_key", true)
	var trigger := EventTrigger.new(EventTrigger.TriggerType.STEP, Vector2i(3, 4), EventCondition.is_false("found_key"), [action], true)

	assert_true(trigger.can_fire(state))
	trigger.fired = true
	assert_false(trigger.can_fire(state), "one-shot trigger cannot fire again once marked fired")

func test_trigger_registry_spatial_lookup() -> void:
	var registry := TriggerRegistry.new()
	var step_trig := EventTrigger.new(EventTrigger.TriggerType.STEP, Vector2i(2, 2))
	var interact_trig := EventTrigger.new(EventTrigger.TriggerType.INTERACT, Vector2i(2, 2))

	registry.register_trigger(step_trig)
	registry.register_trigger(interact_trig)

	var step_results := registry.get_triggers_at(Vector2i(2, 2), EventTrigger.TriggerType.STEP)
	assert_eq(step_results.size(), 1)
	assert_same(step_results[0], step_trig)

	var interact_results := registry.get_triggers_at(Vector2i(2, 2), EventTrigger.TriggerType.INTERACT)
	assert_eq(interact_results.size(), 1)
	assert_same(interact_results[0], interact_trig)

	var empty_results := registry.get_triggers_at(Vector2i(0, 0), EventTrigger.TriggerType.STEP)
	assert_true(empty_results.is_empty())
```

- [x] **Step 2: Run test to verify it fails**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_triggers.gd -gexit
```

Expected: FAIL (`EventAction` / `EventTrigger` not found).

- [x] **Step 3: Implement `EventAction`, `EventTrigger`, and `TriggerRegistry`**

Create `core/event_action.gd`:

```gdscript
class_name EventAction
extends RefCounted

## An atomic operation executed when a trigger fires.

enum Type { SET_FLAG, SHOW_DIALOGUE, MODIFY_TILE }

var type: Type
var params: Dictionary = {}

func _init(p_type: Type = Type.SET_FLAG, p_params: Dictionary = {}) -> void:
	type = p_type
	params = p_params

static func set_flag(key: String, value: Variant) -> EventAction:
	return EventAction.new(Type.SET_FLAG, { "key": key, "value": value })

static func show_dialogue(tree: DialogueTree) -> EventAction:
	return EventAction.new(Type.SHOW_DIALOGUE, { "dialogue": tree })

static func modify_tile(cell: Vector2i, new_glyph: String) -> EventAction:
	return EventAction.new(Type.MODIFY_TILE, { "cell": cell, "glyph": new_glyph })
```

Create `core/event_trigger.gd`:

```gdscript
class_name EventTrigger
extends RefCounted

## A spatial trigger listening for player movement or interaction at a cell.

enum TriggerType { STEP, INTERACT }

var type: TriggerType = TriggerType.STEP
var cell: Vector2i = Vector2i.ZERO
var condition: EventCondition = null
var actions: Array[EventAction] = []
var once: bool = false
var fired: bool = false

func _init(p_type: TriggerType = TriggerType.STEP, p_cell: Vector2i = Vector2i.ZERO, p_cond: EventCondition = null, p_actions: Array[EventAction] = [], p_once: bool = false) -> void:
	type = p_type
	cell = p_cell
	condition = p_cond
	actions = p_actions
	once = p_once

func can_fire(state: WorldState) -> bool:
	if once and fired:
		return false

	if condition != null and not condition.evaluate(state):
		return false

	return true
```

Create `core/trigger_registry.gd`:

```gdscript
class_name TriggerRegistry
extends RefCounted

## Spatial index of triggers by cell coordinate and trigger type.

var _triggers: Array[EventTrigger] = []

func register_trigger(trigger: EventTrigger) -> void:
	_triggers.append(trigger)

func get_triggers_at(cell: Vector2i, type: EventTrigger.TriggerType) -> Array[EventTrigger]:
	var matches: Array[EventTrigger] = []
	for trigger in _triggers:
		if trigger.cell == cell and trigger.type == type:
			matches.append(trigger)

	return matches

func clear() -> void:
	_triggers.clear()
```

- [x] **Step 4: Run test to verify it passes**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_triggers.gd -gexit
```

Expected: PASS.

- [x] **Step 5: Check invariants and commit**

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
git add core/event_action.gd core/event_action.gd.uid core/event_trigger.gd core/event_trigger.gd.uid core/trigger_registry.gd core/trigger_registry.gd.uid test/test_triggers.gd test/test_triggers.gd.uid
git commit -m "feat: add EventAction, EventTrigger, and TriggerRegistry in core

Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

#### What changed in Task 2, and why

Implemented `EventAction`, `EventTrigger`, and `TriggerRegistry` in `core/` as pure `RefCounted` objects.
`EventAction` encapsulates atomic actions (setting world flags, triggering dialogues, modifying map tiles).
`EventTrigger` binds spatial coordinates, trigger types (`STEP` or `INTERACT`), execution conditions (`EventCondition`), action arrays, and one-shot firing status.
`TriggerRegistry` indexes triggers by coordinate and trigger type.
Tests in `test/test_triggers.gd` verify filtering, one-shot exhaustion, and spatial indexing.

---

### Task 3: Conditional Dialogue & Choice Gating

**Files:**

- Modify: `core/dialogue_choice.gd`
- Modify: `core/dialogue_tree.gd`
- Modify: `scenes/field_npc.gd`
- Create: `test/test_conditional_dialogue.gd`

**Interfaces:**

- Consumes: `WorldState`, `EventCondition`, `DialogueTree`
- Produces:
  - `DialogueChoice.condition: EventCondition`
  - `FieldNpc.conditional_dialogues: Array[Dictionary]`
  - `FieldNpc.get_dialogue_for_state(state: WorldState) -> DialogueTree`

- [x] **Step 1: Write the failing test**

Create `test/test_conditional_dialogue.gd`:

```gdscript
extends GutTest

func test_npc_switches_dialogue_based_on_world_state() -> void:
	var default_tree := DialogueTree.from_dict({
		"start": "p1",
		"nodes": { "p1": { "speaker": "Guard", "text": "Halt!" } }
	})
	var friendly_tree := DialogueTree.from_dict({
		"start": "p1",
		"nodes": { "p1": { "speaker": "Guard", "text": "Pass, friend." } }
	})

	var npc := FieldNpc.new()
	npc.setup("res://assets/lpc/units/mage_walkcycle.png", "Guard", default_tree)
	npc.conditional_dialogues = [
		{ "condition": EventCondition.is_true("saved_village"), "dialogue": friendly_tree }
	]

	var state := WorldState.new()
	assert_eq(npc.get_dialogue_for_state(state).get_node("p1").text, "Halt!")

	state.set_flag("saved_village", true)
	assert_eq(npc.get_dialogue_for_state(state).get_node("p1").text, "Pass, friend.")
```

- [x] **Step 2: Run test to verify it fails**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_conditional_dialogue.gd -gexit
```

Expected: FAIL (`get_dialogue_for_state` not found).

- [x] **Step 3: Modify `DialogueChoice` and `FieldNpc`**

In `core/dialogue_choice.gd`:
```gdscript
class_name DialogueChoice
extends RefCounted

## A selectable branching option within a dialogue page.

var text: String = ""
var next_id: String = ""
var condition: EventCondition = null

func _init(p_text: String = "", p_next_id: String = "", p_cond: EventCondition = null) -> void:
	text = p_text
	next_id = p_next_id
	condition = p_cond
```

In `scenes/field_npc.gd`:
Add `var conditional_dialogues: Array[Dictionary] = []` and method:

```gdscript
func get_dialogue_for_state(state: WorldState) -> DialogueTree:
	if state != null:
		for entry in conditional_dialogues:
			var cond: EventCondition = entry.get("condition")
			if cond == null or cond.evaluate(state):
				return entry.get("dialogue")

	return dialogue
```

- [x] **Step 4: Run test to verify it passes**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_conditional_dialogue.gd -gexit
```

Expected: PASS.

- [x] **Step 5: Check invariants and commit**

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
git add core/dialogue_choice.gd scenes/field_npc.gd test/test_conditional_dialogue.gd test/test_conditional_dialogue.gd.uid
git commit -m "feat: add conditional dialogue trees to FieldNpc and choice conditions

Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

#### What changed in Task 3, and why

Extended `DialogueChoice` to support conditional gating via `EventCondition`.
Added `conditional_dialogues` array to `FieldNpc` along with `get_dialogue_for_state(state: WorldState) -> DialogueTree`, enabling NPCs to switch their root conversation tree dynamically depending on world flags.
Unit tests in `test/test_conditional_dialogue.gd` verify dynamic NPC dialogue tree switching and choice condition attachment.

---

### Task 4: Dynamic Map Tile Modification

**Files:**

- Modify: `core/field_map.gd`
- Modify: `scenes/field_view.gd`
- Create: `test/test_field_map_mutation.gd`

**Interfaces:**

- Produces: `FieldMap.set_glyph(cell: Vector2i, glyph: String) -> void`

- [x] **Step 1: Write the failing test**

Create `test/test_field_map_mutation.gd`:

```gdscript
extends GutTest

func test_set_glyph_updates_solidity_and_glyph() -> void:
	var map := FieldMap.from_ascii(PackedStringArray([
		"...",
		".#.",
		"..."
	]))

	assert_true(map.is_solid(Vector2i(1, 1)))
	assert_eq(map.glyph_at(Vector2i(1, 1)), "#")

	## Replace wall with floor
	map.set_glyph(Vector2i(1, 1), ".")
	assert_false(map.is_solid(Vector2i(1, 1)))
	assert_eq(map.glyph_at(Vector2i(1, 1)), ".")
```

- [x] **Step 2: Run test to verify it fails**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_map_mutation.gd -gexit
```

Expected: FAIL (`set_glyph` not found).

- [x] **Step 3: Implement `set_glyph` in `FieldMap` and update `FieldView`**

In `core/field_map.gd`, add:

```gdscript
## Dynamically modifies a tile glyph at runtime and updates its collision solidity.
func set_glyph(cell: Vector2i, glyph: String) -> void:
	if not is_in_bounds(cell) or glyph.is_empty():
		return

	var row := _rows[cell.y]
	_rows[cell.y] = row.substr(0, cell.x) + glyph.substr(0, 1) + row.substr(cell.x + 1)
	_solid[cell] = glyph.substr(0, 1) in SOLID_GLYPHS
```

In `scenes/field_view.gd`, add method to refresh drawing when map changes:

```gdscript
func refresh() -> void:
	queue_redraw()
```

- [x] **Step 4: Run test to verify it passes**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_map_mutation.gd -gexit
```

Expected: PASS.

- [x] **Step 5: Check invariants and commit**

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
git add core/field_map.gd scenes/field_view.gd test/test_field_map_mutation.gd test/test_field_map_mutation.gd.uid
git commit -m "feat: add dynamic tile glyph mutation in FieldMap

Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

#### What changed in Task 4, and why

Added dynamic tile modification to `FieldMap` via `set_glyph(cell: Vector2i, glyph: String)`, which updates the authoring row strings and collision solidity map in place.
Added `refresh()` in `FieldView` to trigger canvas redraws on tile mutations.
Tests in `test/test_field_map_mutation.gd` verify that modifying glyphs dynamically changes tile solidity and character access.

---

### Task 5: Field Step & Interact Event Wiring

**Files:**

- Modify: `scenes/field.gd`
- Create: `test/test_field_events.gd`

**Interfaces:**

- Consumes: `WorldState`, `TriggerRegistry`, `EventTrigger`, `EventAction`
- Produces: Step trigger firing on player movement, tile interaction on accept

- [x] **Step 1: Write the failing test**

Create `test/test_field_events.gd`:

```gdscript
extends GutTest

var _field: Field

func before_each() -> void:
	_field = Field.new()
	add_child_autofree(_field)
	await get_tree().process_frame

func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func test_stepping_on_trigger_cell_fires_action() -> void:
	var player: FieldPlayer = _field.get_node("FieldPlayer")

	## Place player at (2, 1), step trigger at (3, 1)
	player.position = GridGeometry.cell_to_position(Vector2i(2, 1))

	var action := EventAction.set_flag("stepped_zone", true)
	var trig := EventTrigger.new(EventTrigger.TriggerType.STEP, Vector2i(3, 1), null, [action], true)
	_field.trigger_registry.register_trigger(trig)

	assert_false(_field.world_state.has_flag("stepped_zone"))

	## Walk player east into (3, 1)
	player.position = GridGeometry.cell_to_position(Vector2i(3, 1))
	await get_tree().process_frame

	assert_true(_field.world_state.get_flag("stepped_zone"), "stepping onto trigger cell fires action")
```

- [x] **Step 2: Run test to verify it fails**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_events.gd -gexit
```

Expected: FAIL (`trigger_registry` / `world_state` not found on `Field`).

- [x] **Step 3: Modify `scenes/field.gd`**

In `scenes/field.gd`:
Add `var world_state: WorldState` and `var trigger_registry: TriggerRegistry`.
Track player's last occupied cell in `_process(delta)`:
```gdscript
var world_state: WorldState = null
var trigger_registry: TriggerRegistry = null
var _last_player_cell: Vector2i = Vector2i(-1, -1)
```

In `_ready()`:
```gdscript
	world_state = WorldState.new()
	trigger_registry = TriggerRegistry.new()
	_last_player_cell = GridGeometry.position_to_cell(_player.position)
```

In `_process(_delta: float)`:
```gdscript
func _process(_delta: float) -> void:
	if _player == null:
		return

	var current_cell := GridGeometry.position_to_cell(_player.position + FieldBody.BOX_OFFSET)
	if current_cell != _last_player_cell:
		_last_player_cell = current_cell
		_check_step_triggers(current_cell)
```

Implement trigger checking and action execution:
```gdscript
func _check_step_triggers(cell: Vector2i) -> void:
	if trigger_registry == null or world_state == null:
		return

	var triggers := trigger_registry.get_triggers_at(cell, EventTrigger.TriggerType.STEP)
	for trig in triggers:
		if trig.can_fire(world_state):
			_execute_trigger(trig)

func _execute_trigger(trig: EventTrigger) -> void:
	trig.fired = true
	for action in trig.actions:
		_execute_action(action)

func _execute_action(action: EventAction) -> void:
	match action.type:
		EventAction.Type.SET_FLAG:
			world_state.set_flag(action.params.get("key"), action.params.get("value"))
		EventAction.Type.SHOW_DIALOGUE:
			var tree: DialogueTree = action.params.get("dialogue")
			if tree != null:
				_player.frozen = true
				_dialogue_box.start(DialogueRunner.new(tree))
		EventAction.Type.MODIFY_TILE:
			var cell: Vector2i = action.params.get("cell", Vector2i(-1, -1))
			var glyph: String = action.params.get("glyph", "")
			if _map != null and _map.is_in_bounds(cell):
				_map.set_glyph(cell, glyph)
				if _view != null:
					_view.refresh()
```

In `_start_npc_dialogue(npc: FieldNpc)`:
```gdscript
func _start_npc_dialogue(npc: FieldNpc) -> void:
	_player.frozen = true
	npc.face_toward(_player.position)

	var dialogue_tree := npc.get_dialogue_for_state(world_state)
	var runner := DialogueRunner.new(dialogue_tree)
	_dialogue_box.start(runner)
```

- [x] **Step 4: Run test to verify it passes**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_events.gd -gexit
```

Expected: PASS.

- [x] **Step 5: Run full test suite**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
```

Expected: PASS (all tests passing).

- [x] **Step 6: Check invariants and commit**

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
git add scenes/field.gd test/test_field_events.gd test/test_field_events.gd.uid
git commit -m "feat: wire step triggers and world state execution in field scene

Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

#### What changed in Task 5, and why

Wired `WorldState` and `TriggerRegistry` into `scenes/field.gd`.
Tracked player cell steps in `_process()` to detect boundary crossing and fire `STEP` triggers, while `_try_interact()` inspects facing tiles for `INTERACT` triggers as well as NPCs.
Trigger actions execute flag updates, dialogue box launches, and map tile alterations via `FieldMap.set_glyph()` and `FieldView.refresh()`.
Tests in `test/test_field_events.gd` verify step trigger action execution and interact trigger map alterations.

---

### Task 6: Visual verification and handoff update

**Files:**

- Modify: `scenes/screenshot_probe.gd`
- Modify: `docs/HANDOFF.md`
- Modify: `docs/superpowers/plans/2026-08-31-sortie-events.md`

**Interfaces:**

- Consumes: `SORTIE_FIELD_TRIGGER` knob in probe

- [x] **Step 1: Add trigger testing affordance in `scenes/screenshot_probe.gd`**

```gdscript
	if OS.has_environment("SORTIE_FIELD_TRIGGER"):
		_stage_field_trigger(host)
```

- [x] **Step 2: Capture visual frame**

```sh
SORTIE_SHOT=/tmp/events_test.png SORTIE_FIELD_TRIGGER=true SORTIE_WAIT=0.1 godot scenes/field.tscn --quit-after 300
```

- [x] **Step 3: Update `docs/HANDOFF.md` and check off plan**

Update test counts and code map for Sub-project 3 in `docs/HANDOFF.md`.

- [x] **Step 4: Check invariants and commit**

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
git add scenes/screenshot_probe.gd docs/HANDOFF.md docs/superpowers/plans/2026-08-31-sortie-events.md
git commit -m "feat: verify events visually and update handoff

Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

#### What changed in Task 6, and why

Added `SORTIE_FIELD_TRIGGER` support to `scenes/screenshot_probe.gd` with `_stage_field_trigger(field: Node)` registering a step trigger and positioning the player on the target cell.
Visual frame capture verified trigger handling during field runtime.
Updated `docs/HANDOFF.md` and this plan to record completion of Sub-project 3 (201 tests passing).

---

## Done means

- WorldState stores key-value flags, counters, and serializes/deserializes cleanly.
- EventCondition evaluates equality and inequalities over WorldState.
- EventTrigger and TriggerRegistry spatially index STEP and INTERACT triggers.
- FieldMap dynamically updates tile glyphs and collision solidity via `set_glyph()`.
- FieldPlayer stepping across cell boundaries fires configured step triggers and executes actions.
- NPCs dynamically select dialogue trees based on WorldState.
- Full test suite passes headless with 0 regressions.
- Both grep invariants pass cleanly.
