extends SceneTree

const Games = preload("res://game_store.gd")
const Slots = preload("res://save_slots.gd")
const Saves = preload("res://save_store.gd")
const CEO = preload("res://ceo_profile.gd")
const Sim = preload("res://simulation.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)

func run() -> void:
	test_new_games_are_isolated()
	test_explicit_game_data_deletion()
	test_legacy_migration_isolated_deterministic_and_preserved()
	test_deleted_legacy_autosave_is_not_resurrected()
	print("Game scoped persistence: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func test_new_games_are_isolated() -> void:
	var first := Games.create_game("Avery Founder")
	var second := Games.create_game("Avery Founder")
	expect(first.error.is_empty() and second.error.is_empty() and first.game.game_id != second.game.game_id,
		"New games receive unique stable Game IDs even when CEO names match")
	var first_profile: Dictionary = first.profile
	var second_profile: Dictionary = second.profile
	var first_state := Sim.register("Avery Founder", "Northstar Retail", "", 0, 1, 0, 501)
	var second_state := Sim.register("Avery Founder", "Northstar Online", "", 1, 1, 0, 502)
	first_profile = CEO.register_company(first_profile, first_state)
	second_profile = CEO.register_company(second_profile, second_state)
	_set_xp(first_profile, 3000)
	_set_xp(second_profile, 500)
	expect(first_profile.game_id == first.game.game_id and second_profile.game_id == second.game.game_id
		and CEO.company_path_for_game(first_profile.game_id, first_state.company_id) != CEO.company_path_for_game(second_profile.game_id, second_state.company_id),
		"Company archives and career profiles use separate game namespaces")
	expect(Games.write_slot(first.game.game_id, Slots.AUTOSAVE, first_state, first_profile) == OK
		and Games.write_slot(second.game.game_id, Slots.AUTOSAVE, second_state, second_profile) == OK,
		"Each game writes an independent autosave")
	var first_record := Games.read_slot(first.game.game_id, Slots.AUTOSAVE)
	var second_record := Games.read_slot(second.game.game_id, Slots.AUTOSAVE)
	expect(first_record.state.company_id == first_state.company_id and first_record.metadata.game_id == first.game.game_id
		and first_record.metadata.ceo_name == "Avery Founder" and second_record.state.company_id == second_state.company_id,
		"Save envelopes preserve Game ID, CEO identity, company identity, and slot metadata")
	var persisted_first := CEO.load_game_profile(first.game.game_id)
	var persisted_second := CEO.load_game_profile(second.game.game_id)
	expect(persisted_first.xp == 3000 and persisted_second.xp == 500,
		"Career XP remains scoped to the selected game")
	var manually_titled := persisted_first.duplicate(true)
	manually_titled.title = "Managing Director"
	var migrated_title := CEO.migrate_profile(manually_titled)
	expect(not CEO.valid(manually_titled) and migrated_title.title == CEO.progression_title(migrated_title),
		"Career title is derived from game-scoped XP and cannot be persisted as a manual title")
	var renamed := persisted_first.duplicate(true)
	renamed.full_name = "Avery Updated"
	var meta_error := Games.update_game_profile(first.game.game_id, renamed)
	var updated_slot := Games.read_slot(first.game.game_id, Slots.AUTOSAVE)
	expect(meta_error == OK and updated_slot.metadata.ceo_name == "Avery Updated",
		"Profile identity edits update save labels without changing saved company state")
	_clean_game(first.game.game_id)
	_clean_game(second.game.game_id)

func test_explicit_game_data_deletion() -> void:
	var sentinel := CEO.ensure({}, "Global Legacy CEO")
	expect(CEO.save_profile(sentinel) == OK, "Legacy global CEO profile snapshot is created for deletion test")
	var first := Games.create_game("Delete Me CEO")
	var second := Games.create_game("Keep Me CEO")
	var first_state := Sim.register("Delete Me CEO", "Delete Corp", "", 0, 1, 0, 504)
	var second_state := Sim.register("Keep Me CEO", "Keep Corp", "", 0, 1, 0, 505)
	var first_profile: Dictionary = CEO.register_company(first.profile, first_state)
	var second_profile: Dictionary = CEO.register_company(second.profile, second_state)
	Games.write_slot(first.game.game_id, Slots.AUTOSAVE, first_state, first_profile)
	Games.write_slot(second.game.game_id, Slots.AUTOSAVE, second_state, second_profile)
	var delete_result := Games.delete_game_data(first.game.game_id)
	expect(delete_result == OK and Games.get_game(first.game.game_id).is_empty()
		and Games.read_slot(first.game.game_id, Slots.AUTOSAVE).is_empty()
		and CEO.load_game_profile(first.game.game_id).is_empty(),
		"Explicit game-data removal deletes only that game's slots, company archives, profile, and registry entry")
	expect(not Games.read_slot(second.game.game_id, Slots.AUTOSAVE).is_empty()
		and CEO.valid(CEO.load_profile()) and CEO.load_profile().full_name == "Global Legacy CEO",
		"Deleting one game preserves other game saves and the global legacy profile")
	_clean_game(second.game.game_id)
	_clean_profile(CEO.PATH)

func test_legacy_migration_isolated_deterministic_and_preserved() -> void:
	var linked_a := Sim.register("Legacy Founder", "Linked Retail", "", 0, 1, 0, 601)
	var linked_b := Sim.register("Legacy Founder", "Linked Wholesale", "", 1, 1, 0, 602)
	var unlinked := Sim.register("Legacy Founder", "Unlinked Store", "", 2, 1, 0, 603)
	var global_profile := CEO.ensure({}, "Legacy Founder")
	global_profile = CEO.register_company(global_profile, linked_a)
	global_profile = CEO.register_company(global_profile, linked_b)
	_set_xp(global_profile, 7200)
	global_profile.achievements.append({"id": "old-career", "title": "Old Career Achievement"})
	var legacy_achievement_count: int = global_profile.achievements.size()
	var archive_a := CEO.company_path(linked_a.company_id)
	var archive_b := CEO.company_path(linked_b.company_id)
	Saves.save(linked_a, archive_a, 1.0)
	Saves.save(linked_b, archive_b, 2.0)
	CEO.save_profile(global_profile)
	Slots.write(Slots.AUTOSAVE, linked_a, 10.0)
	Slots.write(1, linked_b, 20.0)
	Slots.write(2, unlinked, 30.0)
	Slots.write(3, unlinked, 40.0)
	var originals := [Slots.read(Slots.AUTOSAVE), Slots.read(1), Slots.read(2), Slots.read(3)]
	var result := Games.migrate_legacy()
	expect(result.error.is_empty() and result.migrated_games.size() == 2,
		"Legacy migration groups profile-linked company saves together and separates unlinked company IDs")
	var linked_game_id := _legacy_id_for_profile(global_profile)
	var unlinked_game_id := _legacy_id_for_company(unlinked.company_id)
	var linked_profile := CEO.load_game_profile(linked_game_id)
	var unlinked_profile := CEO.load_game_profile(unlinked_game_id)
	expect(linked_profile.companies.size() == 2 and linked_profile.xp == 7200
		and linked_profile.achievements.size() == legacy_achievement_count and linked_profile.game_id == linked_game_id
		and linked_profile.achievements.any(func(achievement): return str(achievement.get("id", "")) == "old-career"),
		"Known legacy career ownership, XP, achievements, and identity migrate together")
	expect(unlinked_profile.companies.size() == 1 and unlinked_profile.companies[0].company_id == unlinked.company_id
		and unlinked_profile.xp == 0 and unlinked_profile.achievements.is_empty()
		and unlinked_profile.career_start_date.is_empty(),
		"Unlinked legacy save gets an isolated deterministic profile without fabricated career history")
	expect(Games.read_slot(linked_game_id, Slots.AUTOSAVE).state.company_id == linked_a.company_id
		and Games.read_slot(linked_game_id, 1).state.company_id == linked_b.company_id
		and Games.read_slot(unlinked_game_id, 2).state.company_id == unlinked.company_id
		and Games.read_slot(unlinked_game_id, 3).state.company_id == unlinked.company_id,
		"Each old slot copies into its matching isolated game with identity metadata")
	for index in originals.size():
		expect(not originals[index].is_empty() and not Slots.read(index).is_empty(),
			"Legacy source slot %d remains available after migration" % index)
	expect(CEO.load_profile().ceo_id == global_profile.ceo_id and CEO.load_profile().companies.size() == 2,
		"Global CEO profile remains unchanged as a recoverable migration source")
	var repeated := Games.migrate_legacy()
	expect(repeated.error.is_empty() and repeated.already_migrated and Games.list_games().size() == 2,
		"Legacy migration is idempotent and does not duplicate game records")
	_clean_game(linked_game_id)
	_clean_game(unlinked_game_id)
	_clean_profile(CEO.PATH)
	for path in [archive_a, archive_b]: _clean_save(path)
	for slot in range(Slots.COUNT): _clean_save(Slots.path_for(slot))

func test_deleted_legacy_autosave_is_not_resurrected() -> void:
	var state := Sim.register("Deleted Legacy", "Old Deleted Game", "", 0, 1, 0, 777)
	Saves.save(state, Saves.PATH, 55.0)
	var marker := FileAccess.open(Slots.path_for(Slots.AUTOSAVE) + ".deleted", FileAccess.WRITE)
	if marker != null: marker.close()
	expect(Games._read_legacy_slot(Slots.AUTOSAVE).is_empty(),
		"A prior explicit autosave deletion marker prevents migration from resurrecting the old global fallback")
	_clean_save(Saves.PATH)
	_clean_save(Slots.path_for(Slots.AUTOSAVE))

func _legacy_id_for_profile(profile: Dictionary) -> String:
	return "legacy-game-" + _hash("ceo:" + str(profile.ceo_id)).substr(0, 32)

func _legacy_id_for_company(company_id: String) -> String:
	return "legacy-game-" + _hash("company:" + company_id).substr(0, 32)

func _set_xp(profile: Dictionary, xp: int) -> void:
	profile.xp = xp
	profile.title = CEO.progression_title(profile)

func _hash(value: String) -> String:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(value.to_utf8_buffer())
	return hasher.finish().hex_encode().substr(0, 32)

func _clean_game(game_id: String) -> void:
	if not Games.get_game(game_id).is_empty(): Games.delete_game_data(game_id)

func _clean_profile(path: String) -> void:
	for suffix in [".tmp", ".bak", ""]:
		var candidate: String = path + suffix
		if FileAccess.file_exists(candidate): DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))

func _clean_save(path: String) -> void:
	for suffix in [".tmp", ".bak", ".deleted", ""]:
		var candidate: String = path + suffix
		if FileAccess.file_exists(candidate): DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
