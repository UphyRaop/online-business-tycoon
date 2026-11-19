extends RefCounted

const Saves = preload("res://save_store.gd")
const Games = preload("res://game_store.gd")
const AUTOSAVE := 0
const COUNT := 4

static func path_for(slot: int) -> String:
	return "user://business_autosave.save" if slot == AUTOSAVE else "user://business_slot_%d.save" % slot

static func name_for(slot: int) -> String:
	return "Autosave" if slot == AUTOSAVE else "Manual slot %d" % slot

static func write(slot: int, state: Dictionary, timestamp: float = 0) -> Error:
	if slot not in range(COUNT):
		return ERR_INVALID_PARAMETER
	return Saves.save(state, path_for(slot), timestamp if timestamp > 0 else Time.get_unix_time_from_system())

static func occupied(slot: int) -> bool:
	var path := path_for(slot)
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		return true
	return slot == AUTOSAVE and not FileAccess.file_exists(path + ".deleted") and legacy_exists()

static func legacy_exists() -> bool:
	return FileAccess.file_exists(Saves.PATH) or FileAccess.file_exists(Saves.PATH + ".bak") or FileAccess.file_exists(Saves.PROTOTYPE)

static func delete_slot(slot: int) -> Error:
	if slot not in range(COUNT):
		return ERR_INVALID_PARAMETER
	var path := path_for(slot)
	if slot == AUTOSAVE and legacy_exists():
		# A deleted autosave must not reveal the retained pre-slot save again.
		var marker := FileAccess.open(path + ".deleted", FileAccess.WRITE)
		if marker == null:
			return FileAccess.get_open_error()
		marker.close()
	for suffix in [".tmp", ".bak", ""]:
		var file: String = path + suffix
		if FileAccess.file_exists(file):
			var result := DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
			if result != OK:
				return result
	return OK

static func read(slot: int) -> Dictionary:
	if slot not in range(COUNT):
		return {}
	var path := path_for(slot)
	var data := read_with_backup(path)
	if data.is_empty() and slot == AUTOSAVE and not FileAccess.file_exists(path + ".deleted"):
		data = read_with_backup(Saves.PATH)
		if data.is_empty() and FileAccess.file_exists(Saves.PROTOTYPE):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Saves.PROTOTYPE))
			if parsed is Dictionary:
				var legacy := Saves.migrate(parsed)
				if not legacy.is_empty():
					data = {"state": legacy, "saved_at": float(FileAccess.get_modified_time(Saves.PROTOTYPE))}
	if not data.is_empty():
		data.slot = slot
	return data

static func read_with_backup(path: String) -> Dictionary:
	var data := Saves.read_record(path)
	if data.is_empty():
		data = Saves.read_record(path + ".bak")
		if not data.is_empty():
			data.recovered = true
	return data

static func latest() -> Dictionary:
	var best := {}
	for slot in COUNT:
		var data := read(slot)
		if not data.is_empty() and (best.is_empty() or data.saved_at > best.saved_at):
			best = data
	return best

static func timestamp_text(saved_at: float) -> String:
	if saved_at <= 0:
		return "Saved time unavailable"
	var offset: int = Time.get_time_zone_from_system().bias * 60
	return Time.get_datetime_string_from_unix_time(int(saved_at) + offset, true) + " local"

## Game-scoped API. The legacy functions above remain unchanged so saved slots
## from earlier builds can be read and migrated without being overwritten.
static func path_for_game(game_id: String, slot: int) -> String:
	return Games.slot_path(game_id, slot)

static func read_for_game(game_id: String, slot: int) -> Dictionary:
	return Games.read_slot(game_id, slot)

static func write_for_game(game_id: String, slot: int, state: Dictionary, profile: Dictionary, timestamp: float = 0) -> Error:
	return Games.write_slot(game_id, slot, state, profile, timestamp)

static func occupied_for_game(game_id: String, slot: int) -> bool:
	return Games.occupied(game_id, slot)

static func delete_for_game(game_id: String, slot: int) -> Error:
	return Games.delete_slot(game_id, slot)

static func latest_for_game(game_id: String) -> Dictionary:
	return Games.latest(game_id)

static func summary_for_game(game_id: String, slot: int) -> Dictionary:
	return Games.slot_summary(game_id, slot)

static func label_for_game_save(record: Dictionary) -> String:
	return Games.save_label(record)

static func delete_game_data(game_id: String) -> Error:
	return Games.delete_game_data(game_id)
