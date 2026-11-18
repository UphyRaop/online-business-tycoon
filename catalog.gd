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
	{"name": "Value Supply", "factor": 0.90, "quality": 0.85, "minimum": 5, "lead": 4, "reliability": 0.76, "discount": 12, "level": 1, "direct": false, "freight": 1.25, "customs": 0.0, "production": 0, "private_label": false},
	{"name": "Reliable Direct", "factor": 1.0, "quality": 1.0, "minimum": 3, "lead": 2, "reliability": 0.92, "discount": 8, "level": 1, "direct": false, "freight": 2.0, "customs": 0.0, "production": 0, "private_label": false},
	{"name": "Premium Partners", "factor": 1.20, "quality": 1.12, "minimum": 1, "lead": 1, "reliability": 0.98, "discount": 5, "level": 1, "direct": false, "freight": 3.0, "customs": 0.0, "production": 0, "private_label": false},
	{"name": "AliExpress", "factor": 1.27, "quality": 0.90, "minimum": 1, "lead": 6, "reliability": 0.86, "discount": 4, "level": 1, "direct": false, "freight": 1.7, "customs": 0.2, "production": 0, "private_label": false},
	{"name": "CJdropshipping", "factor": 1.12, "quality": 0.93, "minimum": 1, "lead": 5, "reliability": 0.90, "discount": 4, "level": 1, "direct": true, "freight": 1.7, "customs": 0.2, "production": 0, "private_label": false},
	{"name": "EPROLO", "factor": 1.16, "quality": 0.92, "minimum": 1, "lead": 6, "reliability": 0.88, "discount": 4, "level": 1, "direct": true, "freight": 1.7, "customs": 0.2, "production": 0, "private_label": false},
	{"name": "DHgate", "factor": 1.10, "quality": 0.91, "minimum": 1, "lead": 8, "reliability": 0.84, "discount": 4, "level": 1, "direct": false, "freight": 1.7, "customs": 0.2, "production": 0, "private_label": false},
	{"name": "Alibaba.com", "factor": 0.73, "quality": 0.93, "minimum": 20, "lead": 13, "reliability": 0.87, "discount": 8, "level": 2, "direct": false, "freight": 2.4, "customs": 1.0, "production": 5, "private_label": true},
	{"name": "1688.com", "factor": 0.65, "quality": 0.90, "minimum": 30, "lead": 15, "reliability": 0.83, "discount": 8, "level": 2, "direct": false, "freight": 2.4, "customs": 1.0, "production": 7, "private_label": false},
	{"name": "Taobao", "factor": 0.98, "quality": 0.94, "minimum": 5, "lead": 10, "reliability": 0.89, "discount": 8, "level": 2, "direct": false, "freight": 2.4, "customs": 1.0, "production": 0, "private_label": false},
	{"name": "Banggood", "factor": 0.88, "quality": 0.95, "minimum": 10, "lead": 9, "reliability": 0.91, "discount": 8, "level": 2, "direct": false, "freight": 2.4, "customs": 1.0, "production": 0, "private_label": false},
	{"name": "Yiwugo", "factor": 0.70, "quality": 0.92, "minimum": 25, "lead": 16, "reliability": 0.85, "discount": 8, "level": 2, "direct": false, "freight": 2.4, "customs": 1.0, "production": 0, "private_label": false},
	{"name": "Made-in-China.com", "factor": 0.57, "quality": 0.96, "minimum": 60, "lead": 24, "reliability": 0.88, "discount": 12, "level": 3, "direct": false, "freight": 3.1, "customs": 1.4, "production": 16, "private_label": true},
	{"name": "Global Sources", "factor": 0.61, "quality": 0.97, "minimum": 50, "lead": 21, "reliability": 0.87, "discount": 12, "level": 3, "direct": false, "freight": 3.1, "customs": 1.4, "production": 13, "private_label": true},
	{"name": "HyperSKU", "factor": 0.92, "quality": 0.95, "minimum": 1, "lead": 7, "reliability": 0.93, "discount": 12, "level": 3, "direct": true, "freight": 3.1, "customs": 1.4, "production": 0, "private_label": true},
	{"name": "Chinagoods", "factor": 0.66, "quality": 0.93, "minimum": 35, "lead": 20, "reliability": 0.84, "discount": 12, "level": 3, "direct": false, "freight": 3.1, "customs": 1.4, "production": 12, "private_label": false},
	{"name": "IndiaMART", "factor": 0.63, "quality": 0.95, "minimum": 45, "lead": 22, "reliability": 0.86, "discount": 12, "level": 3, "direct": false, "freight": 3.1, "customs": 1.4, "production": 14, "private_label": true},
	{"name": "Global Enterprise Network", "factor": 0.48, "quality": 0.97, "minimum": 100, "lead": 30, "reliability": 0.90, "discount": 16, "level": 4, "direct": false, "freight": 3.8, "customs": 1.8, "production": 22, "private_label": true}
]
const SHIPPING := [
	{"name": "Economy", "cost": 3, "days": 4, "reliability": 0.76},
	{"name": "Standard", "cost": 6, "days": 2, "reliability": 0.91},
	{"name": "Express", "cost": 11, "days": 1, "reliability": 0.98},
]
const INBOUND_PER_UNIT := [1.25, 2.0, 3.0]
const SUPPLIER_THRESHOLDS_USD := [0, 10000, 100000, 1000000]

static func inbound_freight(country: int, supplier: int) -> int:
	return local_cents(country, INBOUND_PER_UNIT[supplier]) if supplier < INBOUND_PER_UNIT.size() else local_cents(country, SUPPLIERS[supplier].freight + SUPPLIERS[supplier].customs)

static func local_cents(country: int, amount: float) -> int:
	return roundi(amount * SCALE[country] * 100)

static func quote(country: int, product: int, supplier: int) -> int:
	return local_cents(country, PRODUCTS[product].cost * SUPPLIERS[supplier].factor)

static func fee(channel: int, price: int) -> int:
	return roundi(price * FEES[channel] / 100.0)
