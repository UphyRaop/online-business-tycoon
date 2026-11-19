extends RefCounted

const Simulation = preload("res://simulation.gd")
const PATH := "user://ceo_profile_v1.json"
const VERSION := 1
const MAX_AVATAR_BYTES := 524288
const LEVEL_XP := 1000
const SALES_MILESTONES := [100000, 1000000, 10000000, 100000000]
const PROFIT_MILESTONES := [100000, 1000000, 10000000]

static func empty(owner: String = "") -> Dictionary:
	return {
		"schema_version": VERSION,
		"ceo_id": "",
		"full_name": owner.strip_edges(),
		"avatar_data": "",
		"avatar_mime": "",
		"country": "",
		"title": "Entrepreneur",
		"xp": 0,
		"achievements": [],
		"awarded_events": [],
		"personal_reputation": 0,
		"personal_cash": null,
		"personal_net_worth": null,
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
		if parsed is Dictionary and valid(parsed):
			parsed.schema_version = VERSION
			parsed.xp = int(parsed.xp)
			return parsed
	return {}

static func save_profile(profile: Dictionary, path: String = PATH) -> Error:
	if not valid(profile):
		return ERR_INVALID_DATA
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(profile))
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
	if not profile.get("achievements") is Array or not profile.get("awarded_events") is Array or not profile.get("companies") is Array:
		return false
	if not (profile.get("personal_cash") == null or _whole_number(profile.personal_cash)):
		return false
	if not (profile.get("personal_net_worth") == null or _whole_number(profile.personal_net_worth)):
		return false
	if profile.avatar_data.length() > int(MAX_AVATAR_BYTES * 4.0 / 3.0) + 16:
		return false
	var company_ids := {}
	for company in profile.companies:
		if not company is Dictionary or not company.get("company_id") is String or company.company_id.is_empty():
			return false
		if company_ids.has(company.company_id):
			return false
		company_ids[company.company_id] = true
	return true

static func _whole_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and floorf(float(value)) == float(value)

static func ensure(profile: Dictionary, owner: String = "") -> Dictionary:
	var result := profile.duplicate(true) if valid(profile) else empty(owner)
	if str(result.ceo_id).is_empty():
		result.ceo_id = _new_id("ceo")
	if str(result.full_name).strip_edges().is_empty() and not owner.strip_edges().is_empty():
		result.full_name = owner.strip_edges()
	return result

static func register_company(profile: Dictionary, state: Dictionary) -> Dictionary:
	var result := ensure(profile, str(state.get("owner", "")))
	var company_id := str(state.get("company_id", ""))
	if company_id.is_empty():
		company_id = _new_id("company")
		state.company_id = company_id
	var index := company_index(result, company_id)
	var entry := {"company_id": company_id, "name": str(state.get("company", "Company")),
		"country": str(state.get("country", "")), "save_path": company_path(company_id),
		"lifetime_sales": 0, "lifetime_profit": 0, "markets": 0, "bankrupt": false}
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
	return true

static func level(profile: Dictionary) -> int:
	return 1 + int(profile.get("xp", 0)) / LEVEL_XP

static func xp_to_next_level(profile: Dictionary) -> int:
	return LEVEL_XP - (int(profile.get("xp", 0)) % LEVEL_XP)

static func company_index(profile: Dictionary, company_id: String) -> int:
	for index in profile.get("companies", []).size():
		if str(profile.companies[index].get("company_id", "")) == company_id:
			return index
	return -1

static func company_path(company_id: String) -> String:
	return "user://ceo_companies/%s.save" % company_id

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
