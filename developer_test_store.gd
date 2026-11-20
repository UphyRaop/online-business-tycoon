extends RefCounted

## Developer test data is kept in a namespace that the normal game save systems
## never read or write. Binary Variant storage preserves integer financial fields exactly.
const ROOT := "user://obt_dev_tests"
const AUDIT_PATH := ROOT + "/audit.jsonl"
const Sim = preload("res://simulation.gd")
const Saves = preload("res://save_store.gd")
const Calendar = preload("res://game_calendar.gd")

static func list_tests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(ROOT)
	if directory == null: return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not directory.current_is_dir() and name.ends_with(".dev"):
			var record := _read(name.trim_suffix(".dev"))
			if not record.is_empty():
				result.append({"id": str(record.get("id", "")), "name": str(record.get("name", "DEV Test")),
					"company": str(record.get("state", {}).get("company", "")), "updated": int(record.get("updated", 0))})
		name = directory.get_next()
	directory.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.updated) > int(b.updated))
	return result

static func create(name: String, source_state: Dictionary, seed: int = 0) -> Dictionary:
	if not OS.is_debug_build(): return {"ok": false, "code": "release_build", "message": "Developer test saves are available only in debug builds."}
	if not Saves.valid(source_state): return {"ok": false, "code": "invalid_source", "message": "The selected source game failed save validation."}
	var cloned: Dictionary = source_state.duplicate(true)
	if seed != 0: cloned.seed = seed
	var record := {"version": 1, "id": _new_id(), "name": _clean_name(name), "created": Time.get_unix_time_from_system(),
		"updated": Time.get_unix_time_from_system(), "snapshot": cloned.duplicate(true), "state": cloned.duplicate(true), "audit": []}
	audit(record, "create_dev_company", "developer_save", "none", {"company": str(cloned.get("company", "")), "seed": int(cloned.get("seed", 0))})
	var error := _write(record)
	if error != OK: return {"ok": false, "code": "storage_error", "message": "Could not create isolated DEV save: " + error_string(error)}
	return {"ok": true, "code": "created", "message": "Isolated DEV test save created.", "record": record}

static func create_fresh(name: String, owner: String, company: String, country: int, difficulty: int, seed: int) -> Dictionary:
	var state := Sim.register(owner, company, "", country, difficulty, 0, seed)
	if state.is_empty(): return {"ok": false, "code": "invalid_company", "message": "The test company settings are invalid."}
	return create(name, state, seed)

static func load_test(id: String) -> Dictionary:
	var record := _read(id)
	if record.is_empty(): return {"ok": false, "code": "not_found", "message": "DEV test save was not found."}
	if not Saves.valid(record.get("state", {})) or not Saves.valid(record.get("snapshot", {})):
		return {"ok": false, "code": "invalid_test_save", "message": "The DEV test save failed validation and was not loaded."}
	return {"ok": true, "code": "loaded", "message": "DEV test save loaded.", "record": record}

static func save_test(record: Dictionary) -> Dictionary:
	if not OS.is_debug_build(): return {"ok": false, "code": "release_build", "message": "Developer test saves are available only in debug builds."}
	if not Saves.valid(record.get("state", {})) or not Saves.valid(record.get("snapshot", {})):
		return {"ok": false, "code": "invalid_test_save", "message": "The updated DEV test save failed validation."}
	record.updated = Time.get_unix_time_from_system()
	var error := _write(record)
	return {"ok": error == OK, "code": "saved" if error == OK else "storage_error",
		"message": "DEV save updated." if error == OK else error_string(error)}

static func reset_test(id: String, to_snapshot: bool = false) -> Dictionary:
	var record := _read(id)
	if record.is_empty(): return {"ok": false, "code": "not_found", "message": "DEV test save was not found."}
	record.state = record.snapshot.duplicate(true) if to_snapshot else Sim.register(
		str(record.snapshot.get("owner", "Test CEO")), str(record.snapshot.get("company", "DEV Test Company")), "",
		int(record.snapshot.get("country", 0)), int(record.snapshot.get("difficulty", 0)),
		int(record.snapshot.get("channel", 0)), int(record.snapshot.get("seed", 1)))
	if record.state.is_empty(): return {"ok": false, "code": "reset_failed", "message": "A fresh DEV baseline could not be created."}
	if to_snapshot and record.has("ceo_snapshot"):
		record.ceo_profile = record.ceo_snapshot.duplicate(true)
	record.audit.append({"action": "reset_dev_save", "date": Calendar.format(int(record.state.day)),
		"target_company": str(record.state.company), "system": "developer_save", "previous": "modified DEV state",
		"new": "baseline", "result": "success"})
	return {"ok": true, "code": "reset", "message": "DEV test save reset.", "record": record}

static func delete_test(id: String) -> Dictionary:
	if not OS.is_debug_build(): return {"ok": false, "code": "release_build", "message": "Developer test saves are available only in debug builds."}
	var path := _path(id)
	if path.is_empty() or not FileAccess.file_exists(path): return {"ok": false, "code": "not_found", "message": "DEV test save was not found."}
	var existing := _read(id)
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not existing.is_empty():
		var state: Dictionary = existing.get("state", {})
		audit_external("delete_dev", "developer_save", id, str(state.get("company", id)), "available DEV save",
			"deleted DEV save" if error == OK else "file remains", "success" if error == OK else "error: " + error_string(error), int(state.get("day", 1)))
	return {"ok": error == OK, "code": "deleted" if error == OK else "storage_error", "message": "DEV test save deleted." if error == OK else error_string(error)}

static func audit(record: Dictionary, action: String, system: String, previous: Variant, value: Variant, result: String = "success") -> void:
	var state: Dictionary = record.get("state", {})
	var event := {"action": action, "simulation_day": int(state.get("day", 0)),
		"simulation_date": Calendar.format(int(state.get("day", 1))), "target_company": str(state.get("company", "")),
		"system": system, "previous": previous, "new": value, "result": result}
	record.audit.append(event)
	while record.audit.size() > 1000: record.audit.pop_front()
	_append_audit_event(event)

static func audit_external(action: String, system: String, target_id: String, target_company: String,
		previous: Variant, value: Variant, result: String, simulation_day: int = 1) -> void:
	_append_audit_event({"action": action, "simulation_day": simulation_day,
		"simulation_date": Calendar.format(maxi(1, simulation_day)), "target_company": target_company,
		"target_id": target_id, "system": system, "previous": previous, "new": value, "result": result})

static func audit_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var file := FileAccess.open(AUDIT_PATH, FileAccess.READ)
	if file == null: return events
	while not file.eof_reached():
		var line := file.get_line()
		if line.strip_edges().is_empty(): continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary: events.append(parsed)
	return events

static func _append_audit_event(event: Dictionary) -> void:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	if directory_error != OK: return
	var path := ProjectSettings.globalize_path(AUDIT_PATH)
	if not FileAccess.file_exists(AUDIT_PATH):
		var created := FileAccess.open(AUDIT_PATH, FileAccess.WRITE)
		if created == null: return
		created.close()
	var file := FileAccess.open(AUDIT_PATH, FileAccess.READ_WRITE)
	if file == null: return
	file.seek_end()
	file.store_line(JSON.stringify(event))
	file.flush()

static func _write(record: Dictionary) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	if directory_error != OK: return directory_error
	var path := _path(str(record.get("id", "")))
	if path.is_empty(): return ERR_INVALID_PARAMETER
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_var(record, true)
	file.flush()
	return file.get_error()

static func _read(id: String) -> Dictionary:
	var path := _path(id)
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed: Variant = file.get_var(false)
	return parsed if parsed is Dictionary and int(parsed.get("version", 0)) == 1 else {}

static func _path(id: String) -> String:
	if id.is_empty() or id.length() > 80: return ""
	for i in id.length():
		var ch := id.substr(i, 1)
		if not ((ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "-"): return ""
	return ROOT.path_join(id + ".dev")

static func _new_id() -> String:
	return "dev-%d-%s" % [Time.get_unix_time_from_system(), Crypto.new().generate_random_bytes(8).hex_encode()]

static func _clean_name(value: String) -> String:
	var name := value.strip_edges().substr(0, 80)
	return name if not name.is_empty() else "DEV Test Company"

