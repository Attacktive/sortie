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
