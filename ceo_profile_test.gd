extends SceneTree

const CEO = preload("res://ceo_profile.gd")
const Sim = preload("res://simulation.gd")
const Saves = preload("res://save_store.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
	else:
		print("PASS: " + message)

func run() -> void:
	test_global_profile_and_achievements()
	test_company_save_independence_and_migration()
	test_avatar_and_corruption_recovery()
	print("CEO profile functional suite: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func test_global_profile_and_achievements() -> void:
	var profile := CEO.ensure({}, "Kai Founder")
	expect(not str(profile.ceo_id).is_empty() and profile.full_name == "Kai Founder", "New CEO profile has a stable unique ID and full name")
	var first := Sim.register("Kai Founder", "Harbor Works", "", 0, 1, 0, 1234)
	profile = CEO.register_company(profile, first)
	expect(profile.companies.size() == 1 and profile.companies[0].company_id == first.company_id, "Profile links the first company by stable company ID")
	var initial_xp: int = profile.xp
	profile = CEO.register_company(profile, first)
	expect(profile.xp == initial_xp and profile.companies.size() == 1, "Repeated registration and save reload cannot farm duplicate company XP")
	first.ledger[0].sales = 100000
	first.ledger[0].channels[0].sales = 100000
	profile = CEO.sync_company(profile, first)
	var sale_xp: int = profile.xp
	profile = CEO.sync_company(profile, first)
	expect(profile.xp == sale_xp and "first_sale" in profile.awarded_events, "First sale XP uses a stable one-time event ID")
	var second := Sim.register("Kai Founder", "Harbor Digital", "", 1, 1, 0, 9876)
	profile = CEO.register_company(profile, second)
	expect(profile.companies.size() == 2 and profile.companies[0].company_id != profile.companies[1].company_id, "Starting another company adds a reference without replacing the first")
	var profile_path := "user://ceo_profile_functional.json"
	expect(CEO.save_profile(profile, profile_path) == OK, "Global CEO profile writes to its separate local profile file")
	var loaded := CEO.load_profile(profile_path)
	expect(loaded.ceo_id == profile.ceo_id and loaded.companies.size() == 2 and loaded.xp == profile.xp, "CEO identity, ownership references, and XP persist independently from company slots")
	var bankruptcy_state := first.duplicate(true)
	bankruptcy_state.cash = -1
	bankruptcy_state.bankrupt = true
	var after_bankruptcy := CEO.sync_company(loaded, bankruptcy_state)
	expect(after_bankruptcy.xp >= sale_xp and "bankruptcy:" + str(first.company_id) in after_bankruptcy.awarded_events, "Career progress survives company bankruptcy")
	_cleanup_profile_files(profile_path)

func test_company_save_independence_and_migration() -> void:
	var first := Sim.register("Kai Founder", "Harbor Works", "", 0, 1, 0, 444)
	var second := Sim.register("Kai Founder", "Harbor Digital", "", 1, 1, 0, 555)
	var first_path := CEO.company_path(first.company_id)
	var second_path := CEO.company_path(second.company_id)
	expect(first_path != second_path and Saves.save(first, first_path, 1.0) == OK and Saves.save(second, second_path, 2.0) == OK,
		"Separate companies can keep independent recoverable saves")
	var first_loaded := Saves.load_state(first_path)
	var second_loaded := Saves.load_state(second_path)
	expect(first_loaded.company == "Harbor Works" and second_loaded.company == "Harbor Digital"
		and first_loaded.company_id == first.company_id and second_loaded.company_id == second.company_id,
		"Switchable company archives load the matching stable ID and business state")
	var legacy := first.duplicate(true)
	legacy.erase("company_id")
	legacy.version = 5
	Sim.upgrade(legacy)
	var legacy_id := str(legacy.company_id)
	var legacy_copy: Dictionary = first.duplicate(true)
	legacy_copy.erase("company_id")
	legacy_copy.version = 5
	Sim.upgrade(legacy_copy)
	expect(legacy_id == legacy_copy.company_id and Saves.valid(legacy), "Legacy save migration assigns a repeatable ID without changing company operations")
	first_loaded.ledger[0].capital += 123
	first_loaded.cash += 123
	expect(Saves.save(first_loaded, first_path, 3.0) == OK and Saves.load_state(second_path).cash == second.cash,
		"Saving one company never overwrites another company archive")
	for path in [first_path, second_path]:
		_cleanup_save_files(path)

func test_avatar_and_corruption_recovery() -> void:
	var profile := CEO.ensure({}, "Kai Founder")
	var tiny_image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	tiny_image.fill(Color(0.4, 0.6, 0.8, 1.0))
	var bytes := tiny_image.save_png_to_buffer()
	expect(CEO.add_avatar(profile, "image/png", bytes) == OK and profile.avatar_mime == "image/jpeg"
		and Marshalls.base64_to_raw(profile.avatar_data).size() <= CEO.MAX_AVATAR_BYTES,
		"JPEG/PNG/WebP input is validated and resized before local avatar storage")
	expect(CEO.add_avatar(profile, "text/plain", bytes) == ERR_INVALID_DATA, "Unsupported avatar file types are rejected")
	var path := "user://ceo_profile_recovery.json"
	expect(CEO.save_profile(profile, path) == OK, "Profile snapshot saved")
	profile.full_name = "Kai Updated"
	expect(CEO.save_profile(profile, path) == OK, "Profile update writes atomically with a backup")
	var damaged := FileAccess.open(path, FileAccess.WRITE)
	if damaged != null:
		damaged.store_string("not valid json")
		damaged.close()
	var recovered := CEO.load_profile(path)
	expect(recovered.full_name == "Kai Founder", "Corrupt profile recovers from its previous valid backup")
	var invalid := CEO.empty("Invalid")
	invalid.xp = -1
	expect(CEO.save_profile(invalid, path) == ERR_INVALID_DATA, "Invalid global profile data cannot replace a valid profile")
	_cleanup_profile_files(path)

func _cleanup_profile_files(path: String) -> void:
	for suffix in [".tmp", ".bak", ""]:
		var candidate := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(candidate)

func _cleanup_save_files(path: String) -> void:
	for suffix in [".tmp", ".bak", ""]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
