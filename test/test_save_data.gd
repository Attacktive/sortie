extends GutTest


func test_save_data_to_dict_and_from_dict_round_trip() -> void:
	var save := SaveData.new()
	save.version = 1
	save.slot_id = 3
	save.timestamp = "2026-09-05 12:34:56"
	save.playtime_seconds = 185.5
	save.location_name = "Whispering Woods"
	save.party_leader = "Mage"
	save.world_state_data = {"talked_to_mage": true, "gold": 100}
	save.field_state_data = {"cell": [4, 7], "facing": 1, "modified_tiles": {"(2, 3)": "."}}

	var dict := save.to_dict()
	assert_eq(dict["version"], 1)
	assert_eq(dict["slot_id"], 3)
	assert_eq(dict["timestamp"], "2026-09-05 12:34:56")
	assert_eq(dict["playtime_seconds"], 185.5)
	assert_eq(dict["location_name"], "Whispering Woods")
	assert_eq(dict["party_leader"], "Mage")
	assert_eq(dict["world_state"]["gold"], 100)
	assert_eq(dict["field_state"]["cell"], [4, 7])

	var restored := SaveData.from_dict(dict)
	assert_not_null(restored)
	assert_eq(restored.version, 1)
	assert_eq(restored.slot_id, 3)
	assert_eq(restored.timestamp, "2026-09-05 12:34:56")
	assert_eq(restored.playtime_seconds, 185.5)
	assert_eq(restored.location_name, "Whispering Woods")
	assert_eq(restored.party_leader, "Mage")
	assert_eq(restored.world_state_data["gold"], 100)
	assert_eq(restored.world_state_data["talked_to_mage"], true)
	assert_eq(restored.field_state_data["cell"], [4, 7])
	assert_eq(restored.field_state_data["facing"], 1)


func test_validate_dict_rejects_missing_keys_or_invalid_types() -> void:
	var valid_dict := {
		"version": 1,
		"slot_id": 1,
		"timestamp": "2026-09-05 00:00:00",
		"playtime_seconds": 0.0,
		"location_name": "Overworld",
		"party_leader": "Vanguard",
		"world_state": {},
		"field_state": {}
	}
	assert_true(SaveData.validate_dict(valid_dict))

	var missing_version := valid_dict.duplicate(true)
	missing_version.erase("version")
	assert_false(SaveData.validate_dict(missing_version))

	var invalid_version := valid_dict.duplicate(true)
	invalid_version["version"] = 0
	assert_false(SaveData.validate_dict(invalid_version))

	var missing_world_state := valid_dict.duplicate(true)
	missing_world_state.erase("world_state")
	assert_false(SaveData.validate_dict(missing_world_state))

	var non_dict_world_state := valid_dict.duplicate(true)
	non_dict_world_state["world_state"] = "not a dict"
	assert_false(SaveData.validate_dict(non_dict_world_state))

	var missing_field_state := valid_dict.duplicate(true)
	missing_field_state.erase("field_state")
	assert_false(SaveData.validate_dict(missing_field_state))


func test_validate_dict_rejects_slot_id_out_of_bounds() -> void:
	var valid_dict := {
		"version": 1,
		"slot_id": 1,
		"timestamp": "2026-09-05 00:00:00",
		"playtime_seconds": 0.0,
		"location_name": "Overworld",
		"party_leader": "Vanguard",
		"world_state": {},
		"field_state": {}
	}

	var slot_zero := valid_dict.duplicate(true)
	slot_zero["slot_id"] = 0
	assert_false(SaveData.validate_dict(slot_zero))

	var slot_eleven := valid_dict.duplicate(true)
	slot_eleven["slot_id"] = 11
	assert_false(SaveData.validate_dict(slot_eleven))


func test_from_dict_returns_null_on_invalid_data() -> void:
	assert_null(SaveData.from_dict({}))
	assert_null(SaveData.from_dict({"version": 1}))
