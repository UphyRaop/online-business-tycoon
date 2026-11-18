extends RefCounted

const ORIGIN := 1767225600
const SECONDS_PER_DAY := 86400
const WEEKDAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const PERIODS := ["Daily", "Weekly", "Monthly", "Yearly"]

static func date_at(day: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(ORIGIN + (day - 1) * SECONDS_PER_DAY)

static func day_at(year: int, month: int, day: int) -> int:
	var unix := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day})
	@warning_ignore("integer_division")
	return (unix - ORIGIN) / SECONDS_PER_DAY + 1

static func format(day: int) -> String:
	var date := date_at(day)
	return "%s, %d %s %d" % [WEEKDAYS[date.weekday], date.day, MONTHS[date.month - 1], date.year]

static func format_range(first: int, last: int) -> String:
	return format(first) if first == last else "%s – %s" % [format(first), format(last)]

static func bounds(period: int, anchor: int) -> Vector2i:
	var date := date_at(anchor)
	match period:
		1:
			var monday := anchor - posmod(date.weekday - 1, 7)
			return Vector2i(monday, monday + 6)
		2:
			var next := day_at(date.year + (1 if date.month == 12 else 0), date.month % 12 + 1, 1)
			return Vector2i(day_at(date.year, date.month, 1), next - 1)
		3:
			return Vector2i(day_at(date.year, 1, 1), day_at(date.year + 1, 1, 1) - 1)
	return Vector2i(anchor, anchor)
