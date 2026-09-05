class_name SaveData
extends RefCounted

## Pure domain data container representing a persistent save state snapshot.
## Serializes to and from plain dictionaries for JSON persistence without engine dependencies.

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
	var field_copy := field_state_data.duplicate(true)
	if field_copy.has("cell") and field_copy["cell"] is Vector2i:
		field_copy["cell"] = [field_copy["cell"].x, field_copy["cell"].y]

	return {
		"version": version,
		"slot_id": slot_id,
		"timestamp": timestamp,
		"playtime_seconds": playtime_seconds,
		"location_name": location_name,
		"party_leader": party_leader,
		"world_state": world_state_data.duplicate(true),
		"field_state": field_copy,
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

	var field_copy: Dictionary = dict.get("field_state", {}).duplicate(true)
	if field_copy.has("cell"):
		if field_copy["cell"] is Array and field_copy["cell"].size() >= 2:
			field_copy["cell"] = Vector2i(int(field_copy["cell"][0]), int(field_copy["cell"][1]))
	if field_copy.has("facing"):
		field_copy["facing"] = int(field_copy["facing"])
	data.field_state_data = field_copy

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
