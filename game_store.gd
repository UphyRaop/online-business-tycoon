extends RefCounted

## Persistent game registry and game-scoped company save/profile storage.
## Legacy root saves are copied into deterministic namespaces; source files are
## intentionally retained so migration can be retried or audited.

const SaveData = preload("res://save_store.gd")
const CEOProfile = preload("res://ceo_profile.gd")
const Simulation = preload("res://simulation.gd")
const REGISTRY_PATH := "user://obt_games/registry.json"
const REGISTRY_VERSION := 1
const SLOT_AUTOSAVE := 0
const SLOT_COUNT := 4

static func create_game(ceo_name: String, game_name: String = "") -> Dictionary:
	var owner := ceo_name.strip_edges()
	if owner.is_empty(): return {"error": "Enter an entrepreneur name before starting a game."}
	var registry := _load_registry()
	if registry.is_empty(): registry = _empty_registry()
	var game_id := _new_game_id()
	var name := game_name.strip_edges()
	if name.is_empty(): name = "%s's Career" % owner
	var created_date := Time.get_date_string_from_system()
	var profile := CEOProfile.ensure_for_game({}, owner, game_id, name)
	profile.career_start_date = created_date
	var profile_result := CEOProfile.save_game_profile(profile, game_id)
	if profile_result != OK:
		return {"error": "Could not create this game's CEO profile. " + error_string(profile_result)}
	var game := {"game_id": game_id, "game_name": name, "ceo_id": str(profile.ceo_id),
		"ceo_name": owner, "created_date": created_date, "career_start_date": created_date,
		"last_played": Time.get_unix_time_from_system(), "legacy": false, "data_deleted": false}
	registry.games.append(game)
	var saved := _save_registry(registry)
	if saved != OK:
		# Do not leave an unlisted profile behind after registry failure.
		_delete_file_family(CEOProfile.path_for_game(game_id))
		return {"error": "Could not save the game registry. " + error_string(saved)}
	return {"error": "", "game": game, "profile": profile}

static func list_games() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for game in _load_registry().get("games", []):
		if game is Dictionary and not game.get("data_deleted", false): result.append(game.duplicate(true))
	return result

static func get_game(game_id: String) -> Dictionary:
	var game := _find_game(_load_registry(), game_id)
	return game.duplicate(true) if not game.is_empty() else {}

static func update_game_profile(game_id: String, profile: Dictionary) -> Error:
	if str(profile.get("game_id", "")) != game_id or not CEOProfile.valid(profile):
		return ERR_INVALID_PARAMETER
	var registry := _load_registry()
	var index := _game_index(registry, game_id)
	if index < 0: return ERR_DOES_NOT_EXIST
	var result := CEOProfile.save_game_profile(profile, game_id)
	if result != OK: return result
	var game: Dictionary = registry.games[index]
	game.ceo_id = str(profile.ceo_id)
	game.ceo_name = str(profile.full_name).strip_edges()
	game.game_name = str(profile.get("game_name", game.game_name)).strip_edges()
	game.career_start_date = str(profile.get("career_start_date", game.get("career_start_date", "")))
	game.last_played = Time.get_unix_time_from_system()
	registry.games[index] = game
	for slot in SLOT_COUNT:
		var record := read_slot(game_id, slot)
		if record.is_empty(): continue
		var metadata := _metadata(game, slot, record.state)
		result = SaveData.save(record.state, slot_path(game_id, slot), float(record.saved_at), metadata)
		if result != OK: return result
		var verified := read_slot(game_id, slot)
		if verified.is_empty() or str(verified.metadata.get("ceo_name", "")) != str(profile.full_name):
			return ERR_FILE_CORRUPT
	return _save_registry(registry)

static func slot_path(game_id: String, slot: int) -> String:
	if not _valid_game_id(game_id) or slot not in range(SLOT_COUNT): return ""
	return "user://obt_games/%s/%s" % [game_id, "autosave.save" if slot == SLOT_AUTOSAVE else "slot_%d.save" % slot]

static func write_slot(game_id: String, slot: int, state: Dictionary, profile: Dictionary,
		timestamp: float = 0) -> Error:
	var path := slot_path(game_id, slot)
	if path.is_empty() or not CEOProfile.valid(profile) or str(profile.get("game_id", "")) != game_id:
		return ERR_INVALID_PARAMETER
	if state.is_empty() or str(state.get("company_id", "")).is_empty(): return ERR_INVALID_DATA
	var index := _game_index(_load_registry(), game_id)
	if index < 0: return ERR_DOES_NOT_EXIST
	var metadata := _metadata(_load_registry().games[index], slot, state)
	if str(state.get("owner", "")).strip_edges() != str(profile.get("full_name", "")).strip_edges():
		return ERR_INVALID_DATA
	var result := CEOProfile.save_game_profile(profile, game_id)
	if result != OK: return result
	result = SaveData.save(state, path, timestamp if timestamp > 0 else Time.get_unix_time_from_system(), metadata)
	if result != OK: return result
	var verified := SaveData.read_record(path)
	if verified.is_empty() or str(verified.get("metadata", {}).get("game_id", "")) != game_id:
		return ERR_FILE_CORRUPT
	return OK

static func read_slot(game_id: String, slot: int) -> Dictionary:
	var path := slot_path(game_id, slot)
	if path.is_empty(): return {}
	var data := SaveData.read_record(path)
	if data.is_empty(): data = SaveData.read_record(path + ".bak")
	if data.is_empty(): return {}
	var metadata: Dictionary = data.get("metadata", {})
	if str(metadata.get("game_id", "")) != game_id or int(metadata.get("slot", -1)) != slot:
		return {}
	if str(metadata.get("company_id", "")) != str(data.state.get("company_id", "")):
		return {}
	data.slot = slot
	data.game_id = game_id
	return data

static func latest(game_id: String) -> Dictionary:
	var result := {}
	for slot in SLOT_COUNT:
		var record := read_slot(game_id, slot)
		if not record.is_empty() and (result.is_empty() or float(record.saved_at) > float(result.saved_at)):
			result = record
	return result

static func slot_summary(game_id: String, slot: int) -> Dictionary:
	var record := read_slot(game_id, slot)
	if record.is_empty(): return {}
	record.game = get_game(game_id)
	record.profile = CEOProfile.load_game_profile(game_id)
	record.display_label = save_label(record)
	return record

static func save_label(record: Dictionary) -> String:
	var metadata: Dictionary = record.get("metadata", {})
	var game_name := str(metadata.get("game_name", "Game"))
	var ceo_name := str(metadata.get("ceo_name", "CEO not recorded"))
	var company_name := str(metadata.get("company_name", "Company"))
	var slot_name := str(metadata.get("slot_name", "Saved game"))
	return "%s · %s · %s · %s" % [game_name, ceo_name, company_name, slot_name]

static func occupied(game_id: String, slot: int) -> bool:
	return not read_slot(game_id, slot).is_empty()

static func delete_slot(game_id: String, slot: int) -> Error:
	var path := slot_path(game_id, slot)
	if path.is_empty(): return ERR_INVALID_PARAMETER
	if _game_index(_load_registry(), game_id) < 0: return ERR_DOES_NOT_EXIST
	return _delete_file_family(path)

static func delete_game_data(game_id: String) -> Error:
	if not _valid_game_id(game_id): return ERR_INVALID_PARAMETER
	var registry := _load_registry()
	var game_index := _game_index(registry, game_id)
	if game_index < 0: return ERR_DOES_NOT_EXIST
	var profile := CEOProfile.load_game_profile(game_id)
	var files: Array[String] = [CEOProfile.path_for_game(game_id)]
	for slot in SLOT_COUNT:
		files.append(slot_path(game_id, slot))
	if not profile.is_empty():
		for company in profile.get("companies", []):
			if company is Dictionary:
				var archive := str(company.get("save_path", ""))
				if archive.begins_with("user://obt_games/%s/companies/" % game_id): files.append(archive)
	for path in files:
		var result := _delete_file_family(path)
		if result != OK: return result
	registry.games.remove_at(game_index)
	return _save_registry(registry)

static func migrate_legacy() -> Dictionary:
	var registry := _load_registry()
	if registry.is_empty(): registry = _empty_registry()
	if bool(registry.get("legacy_migration_complete", false)):
		return {"error": "", "migrated_games": [], "already_migrated": true}
	var legacy_profile := CEOProfile.load_profile(CEOProfile.PATH)
	var linked_ids := {}
	for company in legacy_profile.get("companies", []):
		if company is Dictionary: linked_ids[str(company.get("company_id", ""))] = true
	var groups := {}
	for slot in SLOT_COUNT:
		var record := _read_legacy_slot(slot)
		if record.is_empty(): continue
		var state: Dictionary = record.state
		var company_id := str(state.get("company_id", ""))
		if company_id.is_empty(): continue
		var linked := linked_ids.has(company_id)
		var game_id := _legacy_game_id(str(legacy_profile.get("ceo_id", ""))) if linked else _legacy_company_game_id(company_id)
		if record.get("metadata", {}).has("game_id"):
			# A scoped record is already identified. It is never folded into the
			# pre-namespace legacy group.
			continue
		if not groups.has(game_id):
			groups[game_id] = {"game_id": game_id, "linked": linked, "slots": {}, "company_states": {}, "profile": {}, "game": {}}
		groups[game_id].slots[slot] = record
		groups[game_id].company_states[company_id] = state
	for company in legacy_profile.get("companies", []):
		if not company is Dictionary: continue
		var company_id := str(company.get("company_id", ""))
		if company_id.is_empty(): continue
		var game_id := _legacy_game_id(str(legacy_profile.get("ceo_id", "")))
		if not groups.has(game_id):
			groups[game_id] = {"game_id": game_id, "linked": true, "slots": {}, "company_states": {}, "profile": {}, "game": {}}
	var migrated_ids: Array[String] = []
	var failures: Array[String] = []
	var ordered_ids: Array[String] = []
	for game_id in groups: ordered_ids.append(str(game_id))
	ordered_ids.sort()
	for game_id in ordered_ids:
		var group: Dictionary = groups[game_id]
		var source_profile: Dictionary
		if group.linked:
			source_profile = CEOProfile.ensure_for_game(legacy_profile, str(legacy_profile.get("full_name", "")), game_id, _legacy_game_name(legacy_profile))
		else:
			var state: Dictionary = group.company_states.values()[0]
			source_profile = _unlinked_legacy_profile(game_id, state)
		if source_profile.is_empty():
			failures.append("Could not prepare legacy CEO profile for %s." % game_id)
			continue
		var game := _legacy_game_record(game_id, source_profile, group)
		var error := CEOProfile.save_game_profile(source_profile, game_id)
		if error != OK:
			failures.append("Could not save legacy CEO profile for %s: %s" % [game_id, error_string(error)])
			continue
		if not _copy_company_archives(game_id, source_profile, group):
			failures.append("Could not verify company archive copies for %s." % game_id)
			continue
		var copied_all := true
		for slot in group.slots:
			var record: Dictionary = group.slots[slot]
			var metadata := _metadata(game, int(slot), record.state)
			error = SaveData.save(record.state, slot_path(game_id, int(slot)), float(record.get("saved_at", 0)), metadata)
			var verified := SaveData.read_record(slot_path(game_id, int(slot))) if error == OK else {}
			if error != OK or verified.is_empty() or verified.state.get("company_id", "") != record.state.get("company_id", "") or str(verified.get("metadata", {}).get("game_id", "")) != game_id:
				copied_all = false
				failures.append("Could not verify legacy slot %d for %s." % [int(slot), game_id])
				break
		if not copied_all: continue
		var existing_index := _game_index(registry, game_id)
		if existing_index < 0:
			registry.games.append(game)
		else:
			registry.games[existing_index] = game
		migrated_ids.append(game_id)
	registry.legacy_migration_complete = failures.is_empty()
	registry.legacy_migration_version = 1 if failures.is_empty() else 0
	var registry_error := _save_registry(registry)
	if registry_error != OK: failures.append("Could not commit the game registry: " + error_string(registry_error))
	return {"error": "; ".join(failures), "migrated_games": migrated_ids,
		"already_migrated": false, "legacy_sources_preserved": true}

static func _copy_company_archives(game_id: String, profile: Dictionary, group: Dictionary) -> bool:
	for index in profile.get("companies", []).size():
		var company: Dictionary = profile.companies[index]
		var company_id := str(company.get("company_id", ""))
		if company_id.is_empty(): return false
		var target := CEOProfile.company_path_for_game(game_id, company_id)
		if target.is_empty(): return false
		var source := str(company.get("save_path", CEOProfile.company_path(company_id)))
		var saved := SaveData.read_record(source)
		if saved.is_empty(): saved = SaveData.read_record(source + ".bak")
		if saved.is_empty():
			var state: Dictionary = group.get("company_states", {}).get(company_id, {})
			if state.is_empty():
				company.save_path = source
				continue
			saved = {"state": state, "saved_at": 0.0}
		if str(saved.state.get("company_id", "")) != company_id: return false
		var meta := {"game_id": game_id, "ceo_id": str(profile.ceo_id), "ceo_name": str(profile.full_name),
			"company_id": company_id, "company_name": str(saved.state.get("company", company.get("name", "Company"))),
			"archive": true}
		var error := SaveData.save(saved.state, target, float(saved.get("saved_at", 0)), meta)
		var verify := SaveData.read_record(target) if error == OK else {}
		if error != OK or verify.is_empty() or str(verify.state.get("company_id", "")) != company_id or str(verify.metadata.get("game_id", "")) != game_id:
			return false
		company.save_path = target
		profile.companies[index] = company
	return CEOProfile.save_game_profile(profile, game_id) == OK

static func _unlinked_legacy_profile(game_id: String, state: Dictionary) -> Dictionary:
	var owner := str(state.get("owner", "")).strip_edges()
	var company_id := str(state.get("company_id", ""))
	var game_name := _legacy_company_name(state)
	var profile := CEOProfile.ensure_for_game({}, owner, game_id, game_name)
	profile.ceo_id = "ceo-legacy-" + _hash(game_id, 24)
	profile.career_start_date = ""
	profile.xp = 0
	profile.achievements = []
	profile.awarded_events = []
	var sales := 0
	var profit := 0
	for row in state.get("ledger", []):
		if row is Dictionary:
			sales += int(row.get("sales", 0))
			profit += Simulation.net(row)
	profile.companies = [{"company_id": company_id, "name": str(state.get("company", "Company")),
		"country": str(state.get("country", "")), "save_path": CEOProfile.company_path_for_game(game_id, company_id),
		"lifetime_sales": sales, "lifetime_profit": profit, "markets": 0,
		"bankrupt": bool(state.get("bankrupt", false)), "ownership_status": "owned"}]
	return profile

static func _legacy_game_record(game_id: String, profile: Dictionary, group: Dictionary) -> Dictionary:
	var saved_at := 0.0
	for record in group.get("slots", {}).values(): saved_at = maxf(saved_at, float(record.get("saved_at", 0)))
	var fallback_state: Dictionary = group.get("company_states", {}).values()[0] if not group.get("company_states", {}).is_empty() else {}
	var created_date := str(profile.get("career_start_date", ""))
	var game_name := str(profile.get("game_name", "")).strip_edges()
	if game_name.is_empty(): game_name = _legacy_game_name(profile)
	return {"game_id": game_id, "game_name": game_name,
		"ceo_id": str(profile.get("ceo_id", "")), "ceo_name": str(profile.get("full_name", fallback_state.get("owner", ""))),
		"created_date": created_date, "career_start_date": created_date, "last_played": saved_at,
		"legacy": true, "data_deleted": false}

static func _legacy_game_name(profile: Dictionary) -> String:
	var owner := str(profile.get("full_name", "")).strip_edges()
	return "%s's Legacy Game" % owner if not owner.is_empty() else "Legacy Game"

static func _legacy_company_name(state: Dictionary) -> String:
	return "%s · Legacy Game" % str(state.get("company", "Company"))

static func _read_legacy_slot(slot: int) -> Dictionary:
	if slot not in range(SLOT_COUNT): return {}
	var path := "user://business_autosave.save" if slot == SLOT_AUTOSAVE else "user://business_slot_%d.save" % slot
	var record := SaveData.read_record(path)
	if record.is_empty(): record = SaveData.read_record(path + ".bak")
	if record.is_empty() and slot == SLOT_AUTOSAVE:
		var legacy_autosave_deleted := FileAccess.file_exists(path + ".deleted")
		if not legacy_autosave_deleted:
			record = SaveData.read_record(SaveData.PATH)
			if record.is_empty(): record = SaveData.read_record(SaveData.PATH + ".bak")
		if record.is_empty() and not legacy_autosave_deleted and FileAccess.file_exists(SaveData.PROTOTYPE):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveData.PROTOTYPE))
			if parsed is Dictionary:
				var state := SaveData.migrate(parsed)
				if not state.is_empty(): record = {"state": state, "saved_at": float(FileAccess.get_modified_time(SaveData.PROTOTYPE)), "metadata": {}}
	if not record.is_empty(): record.slot = slot
	return record

static func _metadata(game: Dictionary, slot: int, state: Dictionary) -> Dictionary:
	return {"game_id": str(game.game_id), "game_name": str(game.game_name),
		"ceo_id": str(game.ceo_id), "ceo_name": str(game.ceo_name),
		"company_id": str(state.get("company_id", "")), "company_name": str(state.get("company", "Company")),
		"slot": slot, "slot_name": "Autosave" if slot == SLOT_AUTOSAVE else "Manual slot %d" % slot}

static func _empty_registry() -> Dictionary:
	return {"schema_version": REGISTRY_VERSION, "games": [], "legacy_migration_complete": false,
		"legacy_migration_version": 0}

static func _load_registry() -> Dictionary:
	for path in [REGISTRY_PATH, REGISTRY_PATH + ".bak"]:
		if not FileAccess.file_exists(path): continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and _valid_registry(parsed): return parsed
	return {}

static func _valid_registry(registry: Dictionary) -> bool:
	if int(registry.get("schema_version", 0)) != REGISTRY_VERSION or not registry.get("games") is Array:
		return false
	var seen := {}
	for game in registry.games:
		if not game is Dictionary or not _valid_game_id(str(game.get("game_id", ""))): return false
		for field in ["game_name", "ceo_id", "ceo_name", "created_date", "career_start_date"]:
			if not game.get(field, "") is String: return false
		if not game.get("legacy", false) is bool or not game.get("data_deleted", false) is bool:
			return false
		if seen.has(game.game_id): return false
		seen[game.game_id] = true
	return registry.get("legacy_migration_complete", false) is bool

static func _save_registry(registry: Dictionary) -> Error:
	if not _valid_registry(registry): return ERR_INVALID_DATA
	var directory := ProjectSettings.globalize_path(REGISTRY_PATH).get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS: return directory_error
	var target := ProjectSettings.globalize_path(REGISTRY_PATH)
	var temporary := ProjectSettings.globalize_path(REGISTRY_PATH + ".tmp")
	var backup := ProjectSettings.globalize_path(REGISTRY_PATH + ".bak")
	var file := FileAccess.open(REGISTRY_PATH + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(registry))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	if FileAccess.file_exists(REGISTRY_PATH):
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
		if not old is Dictionary or not _valid_registry(old): return ERR_FILE_CORRUPT
		if FileAccess.file_exists(REGISTRY_PATH + ".bak"):
			error = DirAccess.remove_absolute(backup)
			if error != OK: return error
		error = DirAccess.rename_absolute(target, backup)
		if error != OK: return error
	return DirAccess.rename_absolute(temporary, target)

static func _find_game(registry: Dictionary, game_id: String) -> Dictionary:
	var index := _game_index(registry, game_id)
	return registry.games[index] if index >= 0 else {}

static func _game_index(registry: Dictionary, game_id: String) -> int:
	for index in registry.get("games", []).size():
		if str(registry.games[index].get("game_id", "")) == game_id: return index
	return -1

static func _new_game_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.is_empty(): return "game-" + _hash("%s|%s" % [Time.get_ticks_usec(), randi()], 32)
	return "game-" + bytes.hex_encode()

static func _legacy_game_id(ceo_id: String) -> String:
	return "legacy-game-" + _hash("ceo:" + ceo_id, 32)

static func _legacy_company_game_id(company_id: String) -> String:
	return "legacy-game-" + _hash("company:" + company_id, 32)

static func _hash(value: String, length: int) -> String:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(value.to_utf8_buffer())
	return hasher.finish().hex_encode().substr(0, length)

static func _valid_game_id(game_id: String) -> bool:
	if game_id.is_empty() or game_id.length() > 80: return false
	for index in game_id.length():
		var character := game_id.substr(index, 1)
		if not ((character >= "a" and character <= "z") or (character >= "0" and character <= "9") or character == "-"):
			return false
	return true

static func _delete_file_family(path: String) -> Error:
	if path.is_empty(): return ERR_INVALID_PARAMETER
	for suffix in [".tmp", ".bak", ""]:
		var candidate: String = path + suffix
		if FileAccess.file_exists(candidate):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
			if error != OK: return error
	return OK
