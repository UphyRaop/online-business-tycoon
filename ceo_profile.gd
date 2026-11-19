extends RefCounted

const Simulation = preload("res://simulation.gd")
const PATH := "user://ceo_profile_v1.json"
const VERSION := 3
const MAX_AVATAR_BYTES := 524288
const LEVEL_XP := 1000
const SALES_MILESTONES := [100000, 1000000, 10000000, 100000000]
const PROFIT_MILESTONES := [100000, 1000000, 10000000]

static func empty(owner: String = "") -> Dictionary:
	return {
		"schema_version": VERSION,
		"game_id": "",
		"game_name": "",
		"ceo_id": "",
		"full_name": owner.strip_edges(),
		"avatar_data": "",
		"avatar_mime": "",
		"country": "",
		"title": "Aspiring Entrepreneur",
		"career_start_date": Time.get_date_string_from_system(),
		"xp": 0,
		"achievements": [],
		"awarded_events": [],
		"personal_reputation": 0,
		"personal_cash": null,
		"personal_net_worth": null,
		"personal_finance_ledger": [],
		"companies": [],
	}

static func load_profile(path: String = PATH) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK:
			continue
		var parsed: Variant = parser.data
		if parsed is Dictionary:
			var upgraded := migrate_profile(parsed)
			if valid(upgraded):
				upgraded.xp = int(upgraded.xp)
				return upgraded
	return {}

static func path_for_game(game_id: String) -> String:
	if not _valid_game_id(game_id): return ""
	return "user://obt_games/%s/ceo_profile.json" % game_id

static func load_game_profile(game_id: String) -> Dictionary:
	var path := path_for_game(game_id)
	if path.is_empty(): return {}
	var profile := load_profile(path)
	if profile.is_empty() or str(profile.get("game_id", "")) != game_id:
		return {}
	return profile

static func save_game_profile(profile: Dictionary, game_id: String) -> Error:
	var path := path_for_game(game_id)
	if path.is_empty() or str(profile.get("game_id", "")) != game_id:
		return ERR_INVALID_PARAMETER
	return save_profile(profile, path)

static func save_profile(profile: Dictionary, path: String = PATH) -> Error:
	var normalized := migrate_profile(profile)
	if path.strip_edges().is_empty() or not valid(normalized):
		return ERR_INVALID_DATA
	var directory_path := ProjectSettings.globalize_path(path).get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory_path)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return directory_error
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(normalized))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		return result
	var target := ProjectSettings.globalize_path(path)
	var temp_path := ProjectSettings.globalize_path(temporary)
	var backup := target + ".bak"
	if FileAccess.file_exists(target):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		result = DirAccess.rename_absolute(target, backup)
		if result != OK:
			return result
	return DirAccess.rename_absolute(temp_path, target)

static func valid(profile: Dictionary) -> bool:
	if int(profile.get("schema_version", 0)) != VERSION:
		return false
	for field in ["ceo_id", "full_name", "avatar_data", "avatar_mime", "country", "title"]:
		if not profile.get(field) is String:
			return false
	if not _whole_number(profile.get("xp")) or int(profile.xp) < 0:
		return false
	if not profile.get("game_id", "") is String or not profile.get("game_name", "") is String:
		return false
	if not str(profile.get("game_id", "")).is_empty() and not _valid_game_id(str(profile.game_id)):
		return false
	if not profile.get("achievements") is Array or not profile.get("awarded_events") is Array or not profile.get("companies") is Array:
		return false
	if not profile.get("personal_finance_ledger") is Array:
		return false
	if profile.has("career_start_date") and not profile.career_start_date is String:
		return false
	if not (profile.get("personal_cash") == null or _whole_number(profile.personal_cash)):
		return false
	if not (profile.get("personal_net_worth") == null or _whole_number(profile.personal_net_worth)):
		return false
	if str(profile.get("title", "")) != progression_title(profile):
		return false
	if profile.avatar_data.length() > int(MAX_AVATAR_BYTES * 4.0 / 3.0) + 16:
		return false
	var company_ids := {}
	var sold_company_ids := {}
	for company in profile.companies:
		if not company is Dictionary or not company.get("company_id") is String or company.company_id.is_empty():
			return false
		if str(company.get("ownership_status", "owned")) not in ["owned", "sold"]:
			return false
		if company.get("ownership_status", "owned") == "sold":
			var sale: Variant = company.get("sale_record", {})
			if not sale is Dictionary or not sale.get("record_id") is String or sale.record_id.is_empty():
				return false
			if not _whole_number(sale.get("amount")) or float(sale.amount) < 0 or not _whole_number(sale.get("day")) or float(sale.day) < 1:
				return false
			if str(sale.get("company_id", "")) != str(company.company_id): return false
			sold_company_ids[str(company.company_id)] = str(sale.record_id)
		if company_ids.has(company.company_id):
			return false
		company_ids[company.company_id] = true
	var transaction_ids := {}
	var sold_transaction_companies := {}
	for transaction in profile.personal_finance_ledger:
		if not transaction is Dictionary or str(transaction.get("type", "")) != "company_sale":
			return false
		if not transaction.get("record_id") is String or transaction.record_id.is_empty() or not transaction.get("company_id") is String or transaction.company_id.is_empty():
			return false
		if not _whole_number(transaction.get("amount")) or float(transaction.amount) < 0 or not _whole_number(transaction.get("day")) or float(transaction.day) < 1 or not transaction.get("currency") is String or transaction.currency.is_empty():
			return false
		if transaction_ids.has(transaction.record_id): return false
		transaction_ids[transaction.record_id] = true
		var sold_id := str(transaction.company_id)
		if sold_transaction_companies.has(sold_id) or not sold_company_ids.has(sold_id) or sold_company_ids[sold_id] != str(transaction.record_id): return false
		sold_transaction_companies[sold_id] = true
	if sold_transaction_companies.size() != sold_company_ids.size(): return false
	return true

static func migrate_profile(profile: Dictionary) -> Dictionary:
	var result := profile.duplicate(true)
	var version := int(result.get("schema_version", 0))
	if version not in [1, 2, VERSION]:
		return {}
	if not result.get("game_id") is String:
		result.game_id = ""
	if not result.get("game_name") is String:
		result.game_name = ""
	# A legacy personal balance was never tracked. Preserve null rather than
	# manufacturing a starting balance when introducing the sale-proceeds ledger.
	if not result.get("personal_finance_ledger") is Array:
		result.personal_finance_ledger = []
	if not result.has("personal_cash"):
		result.personal_cash = null
	if not result.has("personal_net_worth"):
		result.personal_net_worth = null
	for index in result.get("companies", []).size():
		var entry: Dictionary = result.companies[index]
		if not entry.has("ownership_status"):
			entry.ownership_status = "owned"
		result.companies[index] = entry
	result.schema_version = VERSION
	result.title = progression_title(result)
	return result

static func _whole_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and floorf(float(value)) == float(value)

static func ensure(profile: Dictionary, owner: String = "") -> Dictionary:
	var migrated := migrate_profile(profile)
	var result := migrated if valid(migrated) else empty(owner)
	if str(result.ceo_id).is_empty():
		result.ceo_id = _new_id("ceo")
	if str(result.full_name).strip_edges().is_empty() and not owner.strip_edges().is_empty():
		result.full_name = owner.strip_edges()
	result.title = progression_title(result)
	return result

static func ensure_for_game(profile: Dictionary, owner: String, game_id: String, game_name: String = "") -> Dictionary:
	if not _valid_game_id(game_id): return {}
	var migrated := migrate_profile(profile)
	var result: Dictionary
	if valid(migrated) and str(migrated.get("game_id", "")).is_empty():
		result = migrated
	elif valid(migrated) and str(migrated.game_id) == game_id:
		result = migrated
	else:
		result = empty(owner)
	result = ensure(result, owner)
	result.game_id = game_id
	if not game_name.strip_edges().is_empty(): result.game_name = game_name.strip_edges()
	return result

static func ensure_legacy(profile: Dictionary, owner: String = "") -> Dictionary:
	var result := ensure(profile, owner)
	if not profile.has("career_start_date"):
		result.career_start_date = ""
	return result

static func register_company(profile: Dictionary, state: Dictionary) -> Dictionary:
	var result := ensure(profile, str(state.get("owner", "")))
	var company_id := str(state.get("company_id", ""))
	if company_id.is_empty():
		company_id = _new_id("company")
		state.company_id = company_id
	var index := company_index(result, company_id)
	var archive_path := company_path_for_game(str(result.get("game_id", "")), company_id) if not str(result.get("game_id", "")).is_empty() else company_path(company_id)
	var entry := {"company_id": company_id, "name": str(state.get("company", "Company")),
		"country": str(state.get("country", "")), "save_path": archive_path,
		"lifetime_sales": 0, "lifetime_profit": 0, "markets": 0, "bankrupt": false,
		"ownership_status": "owned"}
	if index >= 0:
		entry = result.companies[index]
		entry.name = str(state.get("company", entry.get("name", "Company")))
		entry.country = str(state.get("country", entry.get("country", "")))
	else:
		result.companies.append(entry)
	var company_count: int = result.companies.size()
	award(result, "company:" + company_id + ":registered", "company_registered" if company_count == 1 else "company_expansion", 250 if company_count == 1 else 500,
		"First company registered" if company_count == 1 else "Additional company established")
	return result

static func sync_company(profile: Dictionary, state: Dictionary) -> Dictionary:
	var result := register_company(profile, state)
	var company_id := str(state.company_id)
	var index := company_index(result, company_id)
	if index < 0:
		return result
	var entry: Dictionary = result.companies[index]
	var sales := 0
	var profit := 0
	var markets := {}
	for row in state.get("ledger", []):
		if not row is Dictionary:
			continue
		sales += int(row.get("sales", 0))
		profit += Simulation.net(row)
		for channel_index in row.get("channels", []).size():
			if int(row.channels[channel_index].get("sales", 0)) > 0:
				markets[channel_index] = true
	entry.name = str(state.get("company", entry.name))
	entry.country = str(state.get("country", entry.country))
	entry.lifetime_sales = maxi(int(entry.get("lifetime_sales", 0)), sales)
	entry.lifetime_profit = maxi(int(entry.get("lifetime_profit", 0)), profit)
	entry.markets = maxi(int(entry.get("markets", 0)), markets.size())
	entry.bankrupt = bool(entry.get("bankrupt", false)) or bool(state.get("bankrupt", false))
	result.companies[index] = entry
	var ceo_sales := 0
	var ceo_profit := 0
	for company in result.companies:
		ceo_sales += int(company.get("lifetime_sales", 0))
		ceo_profit += int(company.get("lifetime_profit", 0))
	for threshold in SALES_MILESTONES:
		if ceo_sales >= threshold:
			award(result, "sales_milestone:" + str(threshold), "sales_" + str(threshold), 100, "Lifetime sales milestone")
	for threshold in PROFIT_MILESTONES:
		if ceo_profit >= threshold:
			award(result, "profit_milestone:" + str(threshold), "profit_" + str(threshold), 150, "Profitability milestone")
	if sales > 0:
		award(result, "first_sale", "first_sale", 200, "First sale completed")
	var country_ids := {}
	for company in result.companies:
		country_ids[str(company.get("country", ""))] = true
	if country_ids.size() >= 2:
		award(result, "market_expansion", "market_expansion", 150, "Expanded to another market")
	if entry.bankrupt:
		award(result, "bankruptcy:" + company_id, "bankruptcy_survivor", 100, "Company bankruptcy recorded")
	return result

static func award(profile: Dictionary, event_id: String, achievement_id: String, points: int, title: String) -> bool:
	var result := ensure(profile)
	profile.merge(result, true)
	if event_id in profile.awarded_events:
		return false
	profile.awarded_events.append(event_id)
	var found := false
	for achievement in profile.achievements:
		if achievement is Dictionary and str(achievement.get("id", "")) == achievement_id:
			found = true
			break
	if not found:
		profile.achievements.append({"id": achievement_id, "title": title})
	profile.xp += maxi(0, points)
	profile.title = progression_title(profile)
	return true

static func level(profile: Dictionary) -> int:
	return 1 + int(profile.get("xp", 0)) / LEVEL_XP

static func xp_to_next_level(profile: Dictionary) -> int:
	return LEVEL_XP - (int(profile.get("xp", 0)) % LEVEL_XP)

static func progression_title(profile: Dictionary) -> String:
	var current := level(profile)
	if current >= 50: return "Business Tycoon"
	if current >= 40: return "Business Magnate"
	if current >= 30: return "Chief Executive Officer"
	if current >= 20: return "Managing Director"
	if current >= 10: return "Business Owner"
	if current >= 5: return "Startup Founder"
	return "Aspiring Entrepreneur"

static func company_index(profile: Dictionary, company_id: String) -> int:
	for index in profile.get("companies", []).size():
		if str(profile.companies[index].get("company_id", "")) == company_id:
			return index
	return -1

static func owns_company(profile: Dictionary, company_id: String) -> bool:
	var index := company_index(profile, company_id)
	return index >= 0 and str(profile.companies[index].get("ownership_status", "owned")) == "owned"

static func owned_companies(profile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in profile.get("companies", []):
		if entry is Dictionary and str(entry.get("ownership_status", "owned")) == "owned":
			result.append(entry)
	return result

static func company_path(company_id: String) -> String:
	return "user://ceo_companies/%s.save" % company_id

static func company_path_for_game(game_id: String, company_id: String) -> String:
	if not _valid_game_id(game_id) or company_id.strip_edges().is_empty(): return ""
	return "user://obt_games/%s/companies/%s.save" % [game_id, company_id]

static func _valid_game_id(game_id: String) -> bool:
	if game_id.is_empty() or game_id.length() > 80: return false
	for index in game_id.length():
		var character := game_id.substr(index, 1)
		if not ((character >= "a" and character <= "z") or (character >= "0" and character <= "9") or character == "-"):
			return false
	return true

static func add_avatar(profile: Dictionary, mime: String, data: PackedByteArray) -> Error:
	if mime not in ["image/jpeg", "image/png", "image/webp"] or data.is_empty() or data.size() > MAX_AVATAR_BYTES:
		return ERR_INVALID_DATA
	var image := Image.new()
	var error := image.load_jpg_from_buffer(data) if mime == "image/jpeg" else (image.load_png_from_buffer(data) if mime == "image/png" else image.load_webp_from_buffer(data))
	if error != OK or image.is_empty():
		return ERR_INVALID_DATA
	var side := mini(image.get_width(), image.get_height())
	if side <= 0:
		return ERR_INVALID_DATA
	var left := int((image.get_width() - side) / 2)
	var top := int((image.get_height() - side) / 2)
	image = image.get_region(Rect2i(left, top, side, side))
	image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	var jpeg := image.save_jpg_to_buffer(0.82)
	if jpeg.is_empty() or jpeg.size() > MAX_AVATAR_BYTES:
		return ERR_INVALID_DATA
	profile.avatar_data = Marshalls.raw_to_base64(jpeg)
	profile.avatar_mime = "image/jpeg"
	return OK

static func set_avatar_image(profile: Dictionary, image: Image) -> Error:
	if image == null or image.is_empty() or image.get_width() <= 0 or image.get_height() <= 0:
		return ERR_INVALID_DATA
	var finalized := image.duplicate()
	finalized.resize(300, 400, Image.INTERPOLATE_LANCZOS)
	var jpeg: PackedByteArray = finalized.save_jpg_to_buffer(0.84)
	if jpeg.is_empty() or jpeg.size() > MAX_AVATAR_BYTES:
		return ERR_INVALID_DATA
	profile.avatar_data = Marshalls.raw_to_base64(jpeg)
	profile.avatar_mime = "image/jpeg"
	return OK

static func clear_avatar(profile: Dictionary) -> void:
	profile.avatar_data = ""
	profile.avatar_mime = ""

static func _new_id(prefix: String) -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.is_empty():
		return "%s-%s" % [prefix, _stable_id("%s|%s" % [str(Time.get_ticks_usec()), str(randi())])]
	return prefix + "-" + bytes.hex_encode()

static func _stable_id(value: String) -> String:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(value.to_utf8_buffer())
	return hasher.finish().hex_encode().substr(0, 32)
