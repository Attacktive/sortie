# Interaction & Dialogue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the player to walk up to an NPC on the field, face them, press `ui_accept`, and enter a dialogue sequence with speaker names, multi-page text, and branching choices.

**Architecture:** Dialogue data structures, graph traversal, and interaction bounding box geometry live in `core/` as pure `RefCounted` classes. Presentation lives in `ui/` (`dialogue_box.gd`) and `scenes/` (`field_npc.gd`, `field.gd`, `field_player.gd`). The entire dialogue flow and interaction geometry are tested headless.

**Tech Stack:** Godot 4.7.2 stable, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-08-31-sortie-dialogue-design.md`

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

- **All 177 existing tests must keep passing.** Run the full suite:

  ```sh
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
  ```

- **A new `.gd` file needs its `.uid` committed.** Run `godot --headless --import` before `git add`.
- **Commits use `feat`/`fix`/`test`/`docs`.** Add the trailer:
  `Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>`.
- **Do not change `run/main_scene`.** It stays `res://scenes/battle.tscn` until sub-project 4.

---

### Task 1: Core dialogue data model

**Files:**

- Create: `core/dialogue_choice.gd`
- Create: `core/dialogue_node.gd`
- Create: `core/dialogue_tree.gd`
- Create: `test/test_dialogue_tree.gd`

**Interfaces:**

- Produces:
  - `DialogueChoice(text: String, next_id: String)`
  - `DialogueNode(id: String, speaker: String, text: String, next_id: String, choices: Array[DialogueChoice])`
  - `DialogueTree.from_dict(dict: Dictionary) -> DialogueTree`
  - `DialogueTree.get_node(id: String) -> DialogueNode`
  - `DialogueTree.has_node(id: String) -> bool`

- [ ] **Step 1: Write the failing test**

Create `test/test_dialogue_tree.gd`:

```gdscript
extends GutTest

func test_choice_creation() -> void:
	var choice := DialogueChoice.new("Yes", "accept")
	assert_eq(choice.text, "Yes")
	assert_eq(choice.next_id, "accept")

func test_node_creation_and_choice_check() -> void:
	var node := DialogueNode.new("intro", "Guard", "Halt!", "next_step")
	assert_eq(node.id, "intro")
	assert_eq(node.speaker, "Guard")
	assert_eq(node.text, "Halt!")
	assert_eq(node.next_id, "next_step")
	assert_false(node.has_choices())

	node.choices.append(DialogueChoice.new("Option A", "a"))
	assert_true(node.has_choices())

func test_tree_construction_from_dict() -> void:
	var data := {
		"start": "greeting",
		"nodes": {
			"greeting": {
				"speaker": "Elder",
				"text": "Welcome to our village.",
				"choices": [
					{ "text": "Thank you.", "next": "thanks" },
					{ "text": "Where is the inn?", "next": "inn" }
				]
			},
			"thanks": {
				"speaker": "Elder",
				"text": "Rest well.",
				"next": ""
			},
			"inn": {
				"speaker": "Elder",
				"text": "To the east.",
				"next": ""
			}
		}
	}

	var tree := DialogueTree.from_dict(data)
	assert_eq(tree.start_node_id, "greeting")
	assert_true(tree.has_node("greeting"))
	assert_true(tree.has_node("thanks"))
	assert_true(tree.has_node("inn"))
	assert_false(tree.has_node("missing"))

	var greeting := tree.get_node("greeting")
	assert_eq(greeting.speaker, "Elder")
	assert_eq(greeting.choices.size(), 2)
	assert_eq(greeting.choices[0].text, "Thank you.")
	assert_eq(greeting.choices[0].next_id, "thanks")
```

- [ ] **Step 2: Run test to verify it fails**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_dialogue_tree.gd -gexit
```

Expected: FAIL (types not defined).

- [ ] **Step 3: Implement `DialogueChoice`, `DialogueNode`, and `DialogueTree`**

Create `core/dialogue_choice.gd`:

```gdscript
class_name DialogueChoice
extends RefCounted

## A selectable branching option within a dialogue page.

var text: String = ""
var next_id: String = ""

func _init(p_text: String = "", p_next_id: String = "") -> void:
	text = p_text
	next_id = p_next_id
```

Create `core/dialogue_node.gd`:

```gdscript
class_name DialogueNode
extends RefCounted

## A single page of dialogue containing speaker, message text, and navigation links.

var id: String = ""
var speaker: String = ""
var text: String = ""
var next_id: String = ""
var choices: Array[DialogueChoice] = []

func _init(p_id: String = "", p_speaker: String = "", p_text: String = "", p_next_id: String = "") -> void:
	id = p_id
	speaker = p_speaker
	text = p_text
	next_id = p_next_id

func has_choices() -> bool:
	return not choices.is_empty()
```

Create `core/dialogue_tree.gd`:

```gdscript
class_name DialogueTree
extends RefCounted

## A directed graph of dialogue pages indexed by unique string identifiers.

var start_node_id: String = ""
var nodes: Dictionary = {}

func has_node(id: String) -> bool:
	return nodes.has(id)

func get_node(id: String) -> DialogueNode:
	return nodes.get(id, null)

static func from_dict(dict: Dictionary) -> DialogueTree:
	var tree := DialogueTree.new()
	tree.start_node_id = str(dict.get("start", ""))

	var raw_nodes: Dictionary = dict.get("nodes", {})
	for node_id in raw_nodes:
		var node_data: Dictionary = raw_nodes[node_id]
		var node := DialogueNode.new(
			str(node_id),
			str(node_data.get("speaker", "")),
			str(node_data.get("text", "")),
			str(node_data.get("next", ""))
		)

		if node_data.has("choices"):
			var raw_choices: Array = node_data.get("choices", [])
			for raw_choice in raw_choices:
				if raw_choice is Dictionary:
					var choice := DialogueChoice.new(
						str(raw_choice.get("text", "")),
						str(raw_choice.get("next", ""))
					)
					node.choices.append(choice)

		tree.nodes[str(node_id)] = node

	return tree
```

- [ ] **Step 4: Run test to verify it passes**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_dialogue_tree.gd -gexit
```

Expected: PASS (3 tests passed).

- [ ] **Step 5: Check invariants and commit**

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
git add core/dialogue_choice.gd core/dialogue_choice.gd.uid core/dialogue_node.gd core/dialogue_node.gd.uid core/dialogue_tree.gd core/dialogue_tree.gd.uid test/test_dialogue_tree.gd test/test_dialogue_tree.gd.uid
git commit -m "feat: add dialogue data model in core

Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

### Task 2: Core dialogue runner state machine

**Files:**

- Create: `core/dialogue_runner.gd`
- Create: `test/test_dialogue_runner.gd`

**Interfaces:**

- Consumes: `DialogueTree`, `DialogueNode`, `DialogueChoice`
- Produces:
  - `DialogueRunner(tree: DialogueTree)`
  - `DialogueRunner.current_node() -> DialogueNode`
  - `DialogueRunner.advance() -> bool`
  - `DialogueRunner.select_choice(index: int) -> bool`
  - `DialogueRunner.is_finished() -> bool`

- [ ] **Step 1: Write the failing test**

Create `test/test_dialogue_runner.gd`:

```gdscript
extends GutTest

func _make_sample_tree() -> DialogueTree:
	return DialogueTree.from_dict({
		"start": "page1",
		"nodes": {
			"page1": {
				"speaker": "Hero",
				"text": "Hello!",
				"next": "page2"
			},
			"page2": {
				"speaker": "Hero",
				"text": "What do you want?",
				"choices": [
					{ "text": "Fight", "next": "fight" },
					{ "text": "Flee", "next": "flee" }
				]
			},
			"fight": {
				"speaker": "Hero",
				"text": "En garde!",
				"next": ""
			},
			"flee": {
				"speaker": "Hero",
				"text": "Coward!",
				"next": ""
			}
		}
	})

func test_linear_flow_advances_to_completion() -> void:
	var tree := DialogueTree.from_dict({
		"start": "p1",
		"nodes": {
			"p1": { "speaker": "A", "text": "1", "next": "p2" },
			"p2": { "speaker": "A", "text": "2", "next": "" }
		}
	})

	var runner := DialogueRunner.new(tree)
	assert_false(runner.is_finished())
	assert_eq(runner.current_node().text, "1")

	var advanced := runner.advance()
	assert_true(advanced)
	assert_false(runner.is_finished())
	assert_eq(runner.current_node().text, "2")

	advanced = runner.advance()
	assert_false(advanced)
	assert_true(runner.is_finished())
	assert_null(runner.current_node())

func test_choices_prevent_linear_advance() -> void:
	var runner := DialogueRunner.new(_make_sample_tree())
	runner.advance()

	assert_true(runner.current_node().has_choices())
	assert_false(runner.advance(), "cannot linearly advance past a choice prompt")
	assert_false(runner.is_finished())

func test_choice_selection_branches_graph() -> void:
	var runner := DialogueRunner.new(_make_sample_tree())
	runner.advance()

	assert_false(runner.select_choice(-1))
	assert_false(runner.select_choice(5))

	var selected := runner.select_choice(0)
	assert_true(selected)
	assert_eq(runner.current_node().id, "fight")
	assert_eq(runner.current_node().text, "En garde!")

	runner.advance()
	assert_true(runner.is_finished())
```

- [ ] **Step 2: Run test to verify it fails**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_dialogue_runner.gd -gexit
```

Expected: FAIL (`DialogueRunner` not found).

- [ ] **Step 3: Implement `DialogueRunner`**

Create `core/dialogue_runner.gd`:

```gdscript
class_name DialogueRunner
extends RefCounted

## State machine executing a DialogueTree graph.

var tree: DialogueTree = null
var current_node_id: String = ""
var _finished: bool = false

func _init(p_tree: DialogueTree) -> void:
	tree = p_tree
	if tree != null:
		current_node_id = tree.start_node_id
		if not tree.has_node(current_node_id):
			_finished = true
	else:
		_finished = true

func current_node() -> DialogueNode:
	if _finished or tree == null:
		return null

	return tree.get_node(current_node_id)

func is_finished() -> bool:
	return _finished

func advance() -> bool:
	if _finished:
		return false

	var node := current_node()
	if node == null:
		_finished = true
		return false

	if node.has_choices():
		return false

	if node.next_id.is_empty():
		_finished = true
		return false

	if not tree.has_node(node.next_id):
		_finished = true
		return false

	current_node_id = node.next_id
	return true

func select_choice(index: int) -> bool:
	if _finished:
		return false

	var node := current_node()
	if node == null or not node.has_choices():
		return false

	if index < 0 or index >= node.choices.size():
		return false

	var choice := node.choices[index]
	if choice.next_id.is_empty():
		_finished = true
		return true

	if not tree.has_node(choice.next_id):
		_finished = true
		return false

	current_node_id = choice.next_id
	return true
```

- [ ] **Step 4: Run test to verify it passes**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_dialogue_runner.gd -gexit
```

Expected: PASS.

- [ ] **Step 5: Check invariants and commit**

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
git add core/dialogue_runner.gd core/dialogue_runner.gd.uid test/test_dialogue_runner.gd test/test_dialogue_runner.gd.uid
git commit -m "feat: add headless dialogue runner state machine

Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

### Task 3: Core interaction geometry

**Files:**

- Create: `core/interaction.gd`
- Create: `test/test_interaction.gd`

**Interfaces:**

- Consumes: `Facing.Direction`
- Produces: `Interaction.probe_box(box: Rect2, facing: Facing.Direction, reach: float) -> Rect2`

- [ ] **Step 1: Write the failing test**

Create `test/test_interaction.gd`:

```gdscript
extends GutTest

func test_probe_box_extends_in_facing_direction() -> void:
	var box := Rect2(100.0, 100.0, 32.0, 20.0)
	var reach := 16.0

	var up := Interaction.probe_box(box, Facing.Direction.UP, reach)
	assert_eq(up.position, Vector2(100.0, 84.0))
	assert_eq(up.size, Vector2(32.0, 16.0))

	var down := Interaction.probe_box(box, Facing.Direction.DOWN, reach)
	assert_eq(down.position, Vector2(100.0, 120.0))
	assert_eq(down.size, Vector2(32.0, 16.0))

	var left := Interaction.probe_box(box, Facing.Direction.LEFT, reach)
	assert_eq(left.position, Vector2(84.0, 100.0))
	assert_eq(left.size, Vector2(16.0, 20.0))

	var right := Interaction.probe_box(box, Facing.Direction.RIGHT, reach)
	assert_eq(right.position, Vector2(132.0, 100.0))
	assert_eq(right.size, Vector2(16.0, 20.0))

func test_interaction_intersects_adjacent_target() -> void:
	var player_box := Rect2(100.0, 100.0, 32.0, 20.0)
	var target_box := Rect2(100.0, 70.0, 32.0, 20.0)

	var probe_up := Interaction.probe_box(player_box, Facing.Direction.UP)
	var probe_down := Interaction.probe_box(player_box, Facing.Direction.DOWN)

	assert_true(probe_up.intersects(target_box), "facing target reaches it")
	assert_false(probe_down.intersects(target_box), "facing away does not reach it")
```

- [ ] **Step 2: Run test to verify it fails**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_interaction.gd -gexit
```

Expected: FAIL (`Interaction` not found).

- [ ] **Step 3: Implement `Interaction`**

Create `core/interaction.gd`:

```gdscript
class_name Interaction
extends RefCounted

## Pure geometry determining interaction reach from a collision box and facing direction.

const DEFAULT_REACH := 16.0

static func probe_box(box: Rect2, facing: Facing.Direction, reach: float = DEFAULT_REACH) -> Rect2:
	if facing == Facing.Direction.UP:
		return Rect2(box.position.x, box.position.y - reach, box.size.x, reach)

	if facing == Facing.Direction.DOWN:
		return Rect2(box.position.x, box.end.y, box.size.x, reach)

	if facing == Facing.Direction.LEFT:
		return Rect2(box.position.x - reach, box.position.y, reach, box.size.y)

	return Rect2(box.end.x, box.position.y, reach, box.size.y)
```

- [ ] **Step 4: Run test to verify it passes**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_interaction.gd -gexit
```

Expected: PASS.

- [ ] **Step 5: Check invariants and commit**

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
git add core/interaction.gd core/interaction.gd.uid test/test_interaction.gd test/test_interaction.gd.uid
git commit -m "feat: add interaction probe geometry in core

Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

### Task 4: Dialogue Box UI component

**Files:**

- Create: `ui/dialogue_box.gd`
- Create: `test/test_dialogue_box.gd`

**Interfaces:**

- Consumes: `DialogueRunner`, `DialogueNode`, `DialogueChoice`
- Produces:
  - `DialogueBox.start(runner: DialogueRunner)`
  - `DialogueBox.signal finished`
  - `DialogueBox.signal choice_selected(index: int)`

- [ ] **Step 1: Write the failing test**

Create `test/test_dialogue_box.gd`:

```gdscript
extends GutTest

var _box: DialogueBox

func before_each() -> void:
	_box = DialogueBox.new()
	add_child_autofree(_box)
	await get_tree().process_frame

func _make_runner() -> DialogueRunner:
	var tree := DialogueTree.from_dict({
		"start": "q",
		"nodes": {
			"q": {
				"speaker": "Guard",
				"text": "Pass or halt?",
				"choices": [
					{ "text": "Pass", "next": "pass" },
					{ "text": "Halt", "next": "halt" }
				]
			},
			"pass": { "speaker": "Guard", "text": "Move on.", "next": "" },
			"halt": { "speaker": "Guard", "text": "Stay back.", "next": "" }
		}
	})
	return DialogueRunner.new(tree)

func test_dialogue_box_renders_speaker_and_text() -> void:
	var runner := _make_runner()
	_box.start(runner)

	assert_true(_box.visible)
	assert_eq(_box.get_speaker(), "Guard")
	assert_eq(_box.get_text(), "Pass or halt?")
	assert_eq(_box.get_choice_count(), 2)

func test_keyboard_choice_navigation() -> void:
	var runner := _make_runner()
	_box.start(runner)
	assert_eq(_box.get_selected_choice_index(), 0)

	_box.handle_input_action("ui_down")
	assert_eq(_box.get_selected_choice_index(), 1)

	_box.handle_input_action("ui_up")
	assert_eq(_box.get_selected_choice_index(), 0)

func test_accept_advances_and_finishes() -> void:
	var runner := _make_runner()
	_box.start(runner)

	watch_signals(_box)
	_box.handle_input_action("ui_accept")
	assert_eq(_box.get_text(), "Move on.")

	_box.handle_input_action("ui_accept")
	assert_false(_box.visible)
	assert_signal_emitted(_box, "finished")
```

- [ ] **Step 2: Run test to verify it fails**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_dialogue_box.gd -gexit
```

Expected: FAIL (`DialogueBox` not found).

- [ ] **Step 3: Implement `DialogueBox`**

Create `ui/dialogue_box.gd`:

```gdscript
class_name DialogueBox
extends CanvasLayer

## Presentation layer rendering speaker, text, and selectable choices.

signal finished
signal choice_selected(index: int)

var _runner: DialogueRunner = null
var _selected_choice: int = 0

var _panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _choices_container: VBoxContainer
var _choice_labels: Array[Label] = []

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.05
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.68
	_panel.anchor_bottom = 0.95
	add_child(_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	_panel.add_child(layout)

	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	layout.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_text_label)

	_choices_container = VBoxContainer.new()
	layout.add_child(_choices_container)

func start(runner: DialogueRunner) -> void:
	_runner = runner
	_selected_choice = 0
	visible = true
	_refresh()

func _refresh() -> void:
	if _runner == null or _runner.is_finished():
		visible = false
		finished.emit()
		return

	var node := _runner.current_node()
	if node == null:
		visible = false
		finished.emit()
		return

	_speaker_label.text = node.speaker
	_text_label.text = node.text
	_clear_choices()

	if node.has_choices():
		_selected_choice = clampi(_selected_choice, 0, node.choices.size() - 1)
		for i in node.choices.size():
			var choice := node.choices[i]
			var label := Label.new()
			label.text = (" > " if i == _selected_choice else "   ") + choice.text
			_choices_container.add_child(label)
			_choice_labels.append(label)

func _clear_choices() -> void:
	for child in _choices_container.get_children():
		child.queue_free()
	_choice_labels.clear()

func handle_input_action(action: String) -> void:
	if not visible or _runner == null:
		return

	var node := _runner.current_node()
	if node == null:
		return

	if node.has_choices():
		if action == "ui_down":
			_selected_choice = (_selected_choice + 1) % node.choices.size()
			_update_choice_highlight()
		elif action == "ui_up":
			_selected_choice = (_selected_choice - 1 + node.choices.size()) % node.choices.size()
			_update_choice_highlight()
		elif action == "ui_accept":
			var idx := _selected_choice
			_runner.select_choice(idx)
			choice_selected.emit(idx)
			_selected_choice = 0
			_refresh()
	else:
		if action == "ui_accept":
			_runner.advance()
			_refresh()

func _update_choice_highlight() -> void:
	var node := _runner.current_node()
	if node == null or not node.has_choices():
		return

	for i in _choice_labels.size():
		var choice := node.choices[i]
		_choice_labels[i].text = (" > " if i == _selected_choice else "   ") + choice.text

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_down"):
		handle_input_action("ui_down")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		handle_input_action("ui_up")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		handle_input_action("ui_accept")
		get_viewport().set_input_as_handled()

func get_speaker() -> String:
	return _speaker_label.text

func get_text() -> String:
	return _text_label.text

func get_choice_count() -> int:
	return _choice_labels.size()

func get_selected_choice_index() -> int:
	return _selected_choice
```

- [ ] **Step 4: Run test to verify it passes**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_dialogue_box.gd -gexit
```

Expected: PASS.

- [ ] **Step 5: Check invariants and commit**

```sh
git add ui/dialogue_box.gd ui/dialogue_box.gd.uid test/test_dialogue_box.gd test/test_dialogue_box.gd.uid
git commit -m "feat: add DialogueBox UI with keyboard choice navigation

Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

### Task 5: Field NPC Scene

**Files:**

- Create: `scenes/field_npc.gd`
- Create: `test/test_field_npc.gd`

**Interfaces:**

- Consumes: `Facing.Direction`, `DialogueTree`, `FieldBody.BOX_SIZE`, `FieldBody.BOX_OFFSET`
- Produces:
  - `FieldNpc.setup(sheet_path: String, name: String, tree: DialogueTree)`
  - `FieldNpc.get_collision_box() -> Rect2`
  - `FieldNpc.face_toward(target_pos: Vector2)`

- [ ] **Step 1: Write the failing test**

Create `test/test_field_npc.gd`:

```gdscript
extends GutTest

var _npc: FieldNpc

func before_each() -> void:
	_npc = FieldNpc.new()
	_npc.setup("res://assets/lpc/units/mage_walkcycle.png", "Elder", DialogueTree.new())
	_npc.position = Vector2(200.0, 200.0)
	add_child_autofree(_npc)
	await get_tree().process_frame

func test_npc_collision_box_matches_feet_box() -> void:
	var box := _npc.get_collision_box()
	assert_eq(box.position, Vector2(200.0, 200.0) + FieldBody.BOX_OFFSET)
	assert_eq(box.size, FieldBody.BOX_SIZE)

func test_npc_faces_player_on_interaction() -> void:
	_npc.facing = Facing.Direction.DOWN

	## Player is north of NPC (y < 200)
	_npc.face_toward(Vector2(200.0, 100.0))
	assert_eq(_npc.facing, Facing.Direction.UP)

	## Player is east of NPC (x > 200)
	_npc.face_toward(Vector2(300.0, 200.0))
	assert_eq(_npc.facing, Facing.Direction.RIGHT)
```

- [ ] **Step 2: Run test to verify it fails**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_npc.gd -gexit
```

Expected: FAIL (`FieldNpc` not found).

- [ ] **Step 3: Implement `FieldNpc`**

Create `scenes/field_npc.gd`:

```gdscript
class_name FieldNpc
extends Node2D

## An interactive character placed on the field map.

var npc_name: String = ""
var dialogue: DialogueTree = null
var facing: Facing.Direction = Facing.Direction.DOWN

var _sheet: Texture2D = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup(sheet_path: String, p_name: String, p_dialogue: DialogueTree) -> void:
	_sheet = load(sheet_path)
	npc_name = p_name
	dialogue = p_dialogue
	queue_redraw()

func get_collision_box() -> Rect2:
	return FieldBody.box_for_sprite(position)

func face_toward(target_pos: Vector2) -> void:
	facing = Facing.toward(target_pos - position)
	queue_redraw()

func _draw() -> void:
	if _sheet == null:
		return

	var cell := float(GridGeometry.CELL_SIZE)
	var source := Rect2(0.0, int(facing) * cell, cell, cell)

	draw_texture_rect_region(_sheet, Rect2(Vector2.ZERO, Vector2(cell, cell)), source)
```

- [ ] **Step 4: Run test to verify it passes**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_npc.gd -gexit
```

Expected: PASS.

- [ ] **Step 5: Check invariants and commit**

```sh
git add scenes/field_npc.gd scenes/field_npc.gd.uid test/test_field_npc.gd test/test_field_npc.gd.uid
git commit -m "feat: add FieldNpc scene with collision and directional facing

Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

### Task 6: Field interaction wiring & player freeze

**Files:**

- Modify: `scenes/field_player.gd`
- Modify: `scenes/field.gd`
- Create: `test/test_field_interaction.gd`

**Interfaces:**

- Consumes: `Interaction.probe_box()`, `FieldPlayer`, `FieldNpc`, `DialogueBox`
- Produces: `FieldPlayer.frozen`, `field.gd` interaction handler

- [ ] **Step 1: Write the failing test**

Create `test/test_field_interaction.gd`:

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

func test_facing_npc_and_pressing_accept_opens_dialogue_and_freezes_player() -> void:
	var player: FieldPlayer = _field.get_node("FieldPlayer")
	var npc: FieldNpc = _field.get_node("FieldNpc")

	assert_not_null(player)
	assert_not_null(npc)

	## Position player directly south of NPC, facing UP
	player.position = npc.position + Vector2(0.0, 32.0)
	player.facing = Facing.Direction.UP

	## Press ui_accept
	_key(KEY_ENTER, true)
	await get_tree().process_frame
	_key(KEY_ENTER, false)
	await get_tree().process_frame

	var dialogue_box: DialogueBox = _field.get_node("DialogueBox")
	assert_true(dialogue_box.visible, "dialogue box opens on interaction")
	assert_true(player.frozen, "player freezes while dialogue is active")
	assert_eq(npc.facing, Facing.Direction.DOWN, "NPC turns to face the player")

	## Advance and finish dialogue
	_key(KEY_ENTER, true)
	await get_tree().process_frame
	_key(KEY_ENTER, false)
	await get_tree().process_frame

	assert_false(dialogue_box.visible, "dialogue closes after last page")
	assert_false(player.frozen, "player unfreezes after dialogue closes")
```

- [ ] **Step 2: Run test to verify it fails**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_interaction.gd -gexit
```

Expected: FAIL.

- [ ] **Step 3: Update `scenes/field_player.gd` and `scenes/field.gd`**

In `scenes/field_player.gd`:
Add `var frozen: bool = false` and guard `_process`:

```gdscript
var frozen: bool = false
```

In `_process(delta: float)`:
```gdscript
func _process(delta: float) -> void:
	if map == null or frozen:
		_rest()
		return
```

In `scenes/field.gd`:
Spawn an NPC, instantiate `DialogueBox`, and handle `ui_accept` interaction:

```gdscript
extends Node2D

## An interactive ASCII field world with NPC dialogue and camera tracking.

const MAP := [
	"##################",
	"#................#",
	"#..T.............#",
	"#.....TT.........#",
	"#................#",
	"#..........T.....#",
	"#...N............#",
	"#................#",
	"#.......TT.......#",
	"#................#",
	"#................#",
	"##################",
]

var _map: FieldMap
var _view: FieldView
var _player: FieldPlayer
var _camera: Camera2D
var _npc: FieldNpc
var _dialogue_box: DialogueBox

func _ready() -> void:
	_map = FieldMap.from_ascii(PackedStringArray(MAP))

	_build_view()
	_build_npc()
	_build_player()
	_build_camera()
	_build_dialogue_box()

	if OS.has_environment("SORTIE_SHOT"):
		add_child(load("res://scenes/screenshot_probe.gd").new())

func _build_view() -> void:
	_view = FieldView.new()
	_view.map = _map
	_view.setup("res://assets/lpc/terrain/plain_a.png", "res://assets/lpc/terrain/forest.png", "res://assets/lpc/terrain/wall.png")
	add_child(_view)

func _build_npc() -> void:
	_npc = FieldNpc.new()
	_npc.name = "FieldNpc"

	var dialogue := DialogueTree.from_dict({
		"start": "greet",
		"nodes": {
			"greet": {
				"speaker": "Mage",
				"text": "Greetings, traveler. Keep your blade sharp.",
				"next": ""
			}
		}
	})

	_npc.setup("res://assets/lpc/units/mage_walkcycle.png", "Mage", dialogue)
	_npc.position = Vector2(4.0 * GridGeometry.CELL_SIZE, 6.0 * GridGeometry.CELL_SIZE)
	add_child(_npc)

func _build_player() -> void:
	_player = FieldPlayer.new()
	_player.name = "FieldPlayer"
	_player.map = _map
	_player.setup("res://assets/lpc/units/vanguard_walkcycle.png")
	_player.position = Vector2(2.0 * GridGeometry.CELL_SIZE, 2.0 * GridGeometry.CELL_SIZE)
	add_child(_player)

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = _map.width * GridGeometry.CELL_SIZE
	_camera.limit_bottom = _map.height * GridGeometry.CELL_SIZE
	_camera.position = Vector2(GridGeometry.CELL_SIZE * 0.5, GridGeometry.CELL_SIZE * 0.5)
	_player.add_child(_camera)

func _build_dialogue_box() -> void:
	_dialogue_box = DialogueBox.new()
	_dialogue_box.name = "DialogueBox"
	_dialogue_box.finished.connect(_on_dialogue_finished)
	add_child(_dialogue_box)

func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_box.visible:
		return

	if event.is_action_pressed("ui_accept"):
		_try_interact()

func _try_interact() -> void:
	if _player == null or _npc == null:
		return

	var probe := Interaction.probe_box(FieldBody.box_for_sprite(_player.position), _player.facing)
	if probe.intersects(_npc.get_collision_box()):
		_start_npc_dialogue(_npc)

func _start_npc_dialogue(npc: FieldNpc) -> void:
	_player.frozen = true
	npc.face_toward(_player.position)

	var runner := DialogueRunner.new(npc.dialogue)
	_dialogue_box.start(runner)

func _on_dialogue_finished() -> void:
	if _player != null:
		_player.frozen = false
```

- [ ] **Step 4: Run test to verify it passes**

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_field_interaction.gd -gexit
```

Expected: PASS.

- [ ] **Step 5: Run full test suite**

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
```

Expected: PASS (all tests passing).

- [ ] **Step 6: Check invariants and commit**

```sh
grep -rE '\bNode\b|get_tree\(|\bInput\b|preload\(|\.tscn' core/
git add scenes/field_player.gd scenes/field.gd test/test_field_interaction.gd test/test_field_interaction.gd.uid
git commit -m "feat: wire field NPC interaction, player freezing, and dialogue flow

Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

### Task 7: Screenshot probe capture verification and handoff documentation

**Files:**

- Modify: `scenes/screenshot_probe.gd`
- Modify: `docs/HANDOFF.md`
- Modify: `docs/superpowers/plans/2026-08-31-sortie-dialogue.md` (check off items and record writeup)

**Interfaces:**

- Consumes: `SORTIE_FIELD_INTERACT` environment variable in probe

- [ ] **Step 1: Add dialogue capture support to `scenes/screenshot_probe.gd`**

Support `SORTIE_FIELD_INTERACT=true` in `scenes/screenshot_probe.gd`:

```gdscript
	if OS.has_environment("SORTIE_FIELD_INTERACT"):
		host.call("_try_interact")
```

- [ ] **Step 2: Capture dialogue box visually**

```sh
SORTIE_SHOT=/tmp/dialogue_open.png SORTIE_FIELD_INTERACT=true SORTIE_WAIT=0.1 godot scenes/field.tscn --quit-after 300
```

Verify the image shows the player standing near the Mage NPC with the dialogue panel rendered at the bottom.

- [ ] **Step 3: Update `docs/HANDOFF.md`**

Update `docs/HANDOFF.md` to reflect Sub-project 2 completion and the new test count.

- [ ] **Step 4: Commit**

```sh
git add scenes/screenshot_probe.gd docs/HANDOFF.md docs/superpowers/plans/2026-08-31-sortie-dialogue.md
git commit -m "feat: verify dialogue box visually and update handoff

Co-authored-by: Gemini 3.7 Flash <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
```

---

## Done means

- Walking up to an NPC and pressing `ui_accept` opens the dialogue box.
- Linear pages and branching choices advance with keyboard and mouse input.
- Player and NPC face each other during conversation.
- Player cannot move while dialogue is open and resumes freely once closed.
- Full test suite passes headless with 0 regressions.
- Both grep invariants pass cleanly.
