extends RefCounted

const COUNTRIES := ["Malaysia", "United States", "United Kingdom", "Singapore", "Indonesia", "China"]
const CURRENCIES := ["MYR", "USD", "GBP", "SGD", "IDR", "CNY"]
const SCALE := [1.0, 0.25, 0.20, 0.34, 3800.0, 1.7]
const DIFFICULTIES := ["Easy", "Normal", "Hard"]
const CAPITAL := [15000, 5000, 1500]
const OVERHEAD := [4, 6, 9]
const HOSTING := 8
const CHANNELS := ["Marketplace", "Own website", "Both channels"]
const FEES := [12, 4]
const TRAFFIC := [1.0, 0.72]
const PRODUCTS := [
	{"name": "Portable Blender", "cost": 32, "demand": 1.1},
	{"name": "Wireless Earbuds", "cost": 25, "demand": 1.25},
	{"name": "Travel Organizer", "cost": 14, "demand": 0.9},
	{"name": "Desk Lamp", "cost": 29, "demand": 1.0},
	{"name": "Water Bottle", "cost": 12, "demand": 1.15},
]
const SUPPLIERS := [
	{"name": "Value Supply", "factor": 0.90, "quality": 0.85, "minimum": 5, "lead": 4, "reliability": 0.76, "discount": 12},
	{"name": "Reliable Direct", "factor": 1.0, "quality": 1.0, "minimum": 3, "lead": 2, "reliability": 0.92, "discount": 8},
	{"name": "Premium Partners", "factor": 1.20, "quality": 1.12, "minimum": 1, "lead": 1, "reliability": 0.98, "discount": 5},
]
const SHIPPING := [
	{"name": "Economy", "cost": 3, "days": 4, "reliability": 0.76},
	{"name": "Standard", "cost": 6, "days": 2, "reliability": 0.91},
	{"name": "Express", "cost": 11, "days": 1, "reliability": 0.98},
]
const INBOUND_PER_UNIT := [1.25, 2.0, 3.0]

static func inbound_freight(country: int, supplier: int) -> int:
	return local_cents(country, INBOUND_PER_UNIT[supplier])

static func local_cents(country: int, amount: float) -> int:
	return roundi(amount * SCALE[country] * 100)

static func quote(country: int, product: int, supplier: int) -> int:
	return local_cents(country, PRODUCTS[product].cost * SUPPLIERS[supplier].factor)

static func fee(channel: int, price: int) -> int:
	return roundi(price * FEES[channel] / 100.0)
