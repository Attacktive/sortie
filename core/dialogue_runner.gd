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
