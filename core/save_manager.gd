class_name SaveManager
extends RefCounted

## Manages disk persistence for save files across fixed slots.
## Uses atomic temporary writes to protect against partial file corruption.

const MAX_SLOTS := 10
const DEFAULT_SAVE_DIR := "user://saves"

enum Result {
	OK,
	ERR_INVALID_SLOT,
	ERR_FILE_WRITE,
	ERR_FILE_READ,
	ERR_PARSE_JSON,
	ERR_VALIDATION_FAILED,
}

var base_dir: String = DEFAULT_SAVE_DIR


func get_slot_path(slot_id: int) -> String:
	return "%s/slot_%02d.json" % [base_dir, slot_id]


func save_slot(data: SaveData) -> Result:
	if data == null or data.slot_id < 1 or data.slot_id > MAX_SLOTS:
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


func delete_slot(slot_id: int) -> bool:
	if slot_id < 1 or slot_id > MAX_SLOTS:
		return false

	var path := get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return false

	return DirAccess.remove_absolute(path) == OK


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
	if slot_id < 1 or slot_id > MAX_SLOTS:
		return summary

	var path := get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return summary

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return summary

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(content) == OK and (json.data is Dictionary):
		var d: Dictionary = json.data
		if SaveData.validate_dict(d):
			summary["is_empty"] = false
			summary["timestamp"] = d.get("timestamp", "")
			summary["playtime_seconds"] = float(d.get("playtime_seconds", 0.0))
			summary["location_name"] = str(d.get("location_name", "Unknown"))
			summary["party_leader"] = str(d.get("party_leader", ""))

	return summary
