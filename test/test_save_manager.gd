extends GutTest

const TEST_DIR := "user://test_saves"

var _manager: SaveManager = null


func before_each() -> void:
	_manager = SaveManager.new()
	_manager.base_dir = TEST_DIR
	_clean_test_dir()


func after_each() -> void:
	_clean_test_dir()


func _clean_test_dir() -> void:
	if DirAccess.dir_exists_absolute(TEST_DIR):
		var dir := DirAccess.open(TEST_DIR)
		if dir != null:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while not file_name.is_empty():
				if not dir.current_is_dir():
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(TEST_DIR)


func test_save_and_load_slot_round_trip() -> void:
	var save := SaveData.new()
	save.slot_id = 2
	save.timestamp = "2026-09-05 15:00:00"
	save.playtime_seconds = 120.0
	save.location_name = "Castle Gates"
	save.party_leader = "Vanguard"
	save.world_state_data = {"gate_unlocked": true}
	save.field_state_data = {"cell": Vector2i(2, 1), "facing": 0}

	var save_result := _manager.save_slot(save)
	assert_eq(save_result, SaveManager.Result.OK)

	var loaded := _manager.load_slot(2)
	assert_not_null(loaded)
	assert_eq(loaded.slot_id, 2)
	assert_eq(loaded.timestamp, "2026-09-05 15:00:00")
	assert_eq(loaded.playtime_seconds, 120.0)
	assert_eq(loaded.location_name, "Castle Gates")
	assert_eq(loaded.party_leader, "Vanguard")
	assert_eq(loaded.world_state_data["gate_unlocked"], true)
	assert_eq(loaded.field_state_data["cell"], Vector2i(2, 1))


func test_atomic_write_leaves_no_stray_tmp_file() -> void:
	var save := SaveData.new()
	save.slot_id = 1
	save.world_state_data = {}
	save.field_state_data = {}

	var result := _manager.save_slot(save)
	assert_eq(result, SaveManager.Result.OK)

	var final_path := _manager.get_slot_path(1)
	var tmp_path := final_path + ".tmp"
	assert_true(FileAccess.file_exists(final_path))
	assert_false(FileAccess.file_exists(tmp_path))


func test_get_slot_summaries_reports_empty_and_populated_slots() -> void:
	var summaries := _manager.get_slot_summaries()
	assert_eq(summaries.size(), 10)
	for summary in summaries:
		assert_true(summary["is_empty"])

	var save := SaveData.new()
	save.slot_id = 5
	save.timestamp = "2026-09-05 18:30:00"
	save.playtime_seconds = 300.5
	save.location_name = "Forest Path"
	save.party_leader = "Mage"
	save.world_state_data = {}
	save.field_state_data = {}
	_manager.save_slot(save)

	var updated_summaries := _manager.get_slot_summaries()
	assert_eq(updated_summaries.size(), 10)
	assert_true(updated_summaries[0]["is_empty"])
	assert_false(updated_summaries[4]["is_empty"])
	assert_eq(updated_summaries[4]["slot_id"], 5)
	assert_eq(updated_summaries[4]["timestamp"], "2026-09-05 18:30:00")
	assert_eq(updated_summaries[4]["playtime_seconds"], 300.5)
	assert_eq(updated_summaries[4]["location_name"], "Forest Path")


func test_load_slot_corrupted_json_returns_null_safely() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var path := _manager.get_slot_path(3)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ this is corrupted json }}}")
	file.close()

	var loaded := _manager.load_slot(3)
	assert_null(loaded)

	var summary := _manager.get_slot_summary(3)
	assert_true(summary["is_empty"])


func test_delete_slot_removes_file_and_updates_summary() -> void:
	var save := SaveData.new()
	save.slot_id = 4
	save.world_state_data = {}
	save.field_state_data = {}
	_manager.save_slot(save)

	assert_true(FileAccess.file_exists(_manager.get_slot_path(4)))
	var deleted := _manager.delete_slot(4)
	assert_true(deleted)
	assert_false(FileAccess.file_exists(_manager.get_slot_path(4)))

	var summary := _manager.get_slot_summary(4)
	assert_true(summary["is_empty"])
