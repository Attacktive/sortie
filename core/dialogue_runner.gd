class_name DialogueRunner
extends RefCounted

## Traverses a DialogueTree graph node by node, enforcing linear progression or choice branching.
## Keeps dialogue execution pure and testable headless without tying graph traversal to UI timers, animations, or input events.

var tree: DialogueTree = null
var world_state: WorldState = null
var current_node_id: String = ""
var _finished: bool = false

func _init(p_tree: DialogueTree, p_state: WorldState = null) -> void:
	world_state = p_state
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

## Advances to the next linear dialogue node; blocked if the current node has branching choices.
## Reaching an empty or missing node id marks the runner finished.
func advance() -> bool:
	if _finished:
		return false

	var node := current_node()
	if node == null:
		_finished = true
		return false

	if has_available_choices():
		return false

	if node.next_id.is_empty():
		_finished = true
		return false

	if not tree.has_node(node.next_id):
		_finished = true
		return false

	current_node_id = node.next_id
	return true

## Returns all choices on the current node whose conditions evaluate to true against world state.
## Choices without conditions are always available; failed conditions are filtered out and unreachable.
func get_available_choices() -> Array[DialogueChoice]:
	var node := current_node()
	if node == null:
		return []

	var available: Array[DialogueChoice] = []
	for choice in node.choices:
		if choice.condition == null or choice.condition.evaluate(world_state):
			available.append(choice)

	return available

## Reports whether the current node has at least one choice whose condition is satisfied.
func has_available_choices() -> bool:
	return not get_available_choices().is_empty()

## Branches dialogue to the node pointed to by the selected available choice index.
## Returns false if index is out of bounds of available choices or traversal cannot continue.
func select_choice(index: int) -> bool:
	if _finished:
		return false

	var available := get_available_choices()
	if available.is_empty():
		return false

	if index < 0 or index >= available.size():
		return false

	var choice := available[index]
	if choice.next_id.is_empty():
		_finished = true
		return true

	if not tree.has_node(choice.next_id):
		_finished = true
		return false

	current_node_id = choice.next_id
	return true
