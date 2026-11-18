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
	{"name": "AliExpress", "country": "China", "model": "Retail sourcing", "level": 1, "products": [0, 1, 2, 3, 4],
		"factor": 1.27, "minimum": 1, "lead": 6, "quality": 0.90, "reliability": 0.83, "discount": 8,
		"freight": 1.6, "customs": 0, "direct": false, "production": 0, "private_label": false},
	{"name": "CJdropshipping", "country": "China", "model": "Dropshipping", "level": 1, "products": [0, 1, 2, 3, 4],
		"factor": 1.1, "minimum": 1, "lead": 5, "quality": 0.94, "reliability": 0.86, "discount": 8,
		"freight": 2.8, "customs": 0, "direct": true, "production": 0, "private_label": false},
	{"name": "EPROLO", "country": "China", "model": "Dropshipping", "level": 1, "products": [0, 1, 2, 3, 4],
		"factor": 1.16, "minimum": 1, "lead": 6, "quality": 0.98, "reliability": 0.89, "discount": 8,
		"freight": 2.5, "customs": 0, "direct": true, "production": 0, "private_label": false},
	{"name": "DHgate", "country": "China", "model": "International wholesale", "level": 1, "products": [0, 1, 2, 3, 4],
		"factor": 1.09, "minimum": 1, "lead": 8, "quality": 1.02, "reliability": 0.92, "discount": 8,
		"freight": 2.5, "customs": 0.4, "direct": false, "production": 0, "private_label": false},
	{"name": "Print-on-demand Studio", "country": "Malaysia", "model": "Print-on-demand", "level": 1, "products": [4],
		"factor": 1.44, "minimum": 1, "lead": 6, "quality": 1.06, "reliability": 0.95, "discount": 8,
		"freight": 2.7, "customs": 0, "direct": true, "production": 3, "private_label": false},
	{"name": "Alibaba.com", "country": "China", "model": "International wholesale", "level": 2, "products": [0, 1, 2, 3, 4],
		"factor": 0.73, "minimum": 20, "lead": 13, "quality": 0.90, "reliability": 0.83, "discount": 12,
		"freight": 4, "customs": 1.2, "direct": false, "production": 6, "private_label": true},
	{"name": "1688.com", "country": "China", "model": "Domestic wholesale via forwarder", "level": 2, "products": [0, 1, 2, 3, 4],
		"factor": 0.65, "minimum": 30, "lead": 15, "quality": 0.94, "reliability": 0.86, "discount": 12,
		"freight": 5, "customs": 1.6, "direct": false, "production": 8, "private_label": false},
	{"name": "Taobao", "country": "China", "model": "Retail via sourcing agent", "level": 2, "products": [0, 1, 2, 3, 4],
		"factor": 0.98, "minimum": 5, "lead": 10, "quality": 0.98, "reliability": 0.89, "discount": 12,
		"freight": 4, "customs": 1, "direct": false, "production": 0, "private_label": false},
	{"name": "Banggood", "country": "China", "model": "International wholesale", "level": 2, "products": [0, 1, 2, 3, 4],
		"factor": 0.88, "minimum": 10, "lead": 9, "quality": 1.02, "reliability": 0.92, "discount": 12,
		"freight": 3, "customs": 1, "direct": false, "production": 0, "private_label": false},
	{"name": "Yiwugo", "country": "China", "model": "Domestic wholesale via forwarder", "level": 2, "products": [0, 1, 2, 3, 4],
		"factor": 0.7, "minimum": 25, "lead": 16, "quality": 1.06, "reliability": 0.95, "discount": 12,
		"freight": 4.5, "customs": 1.5, "direct": false, "production": 9, "private_label": false},
	{"name": "Made-in-China.com", "country": "China", "model": "Manufacturing / OEM", "level": 3, "products": [0, 1, 3],
		"factor": 0.57, "minimum": 60, "lead": 24, "quality": 0.90, "reliability": 0.83, "discount": 16,
		"freight": 5.5, "customs": 2, "direct": false, "production": 17, "private_label": true},
	{"name": "Global Sources", "country": "Hong Kong", "model": "Directory-sourced factory", "level": 3, "products": [0, 1, 2, 3, 4],
		"factor": 0.61, "minimum": 50, "lead": 21, "quality": 0.94, "reliability": 0.86, "discount": 16,
		"freight": 5, "customs": 2.2, "direct": false, "production": 14, "private_label": true},
	{"name": "HyperSKU", "country": "China", "model": "Dropshipping and private label", "level": 3, "products": [0, 1, 3],
		"factor": 0.92, "minimum": 1, "lead": 7, "quality": 0.98, "reliability": 0.89, "discount": 16,
		"freight": 4, "customs": 1, "direct": true, "production": 0, "private_label": true},
	{"name": "Chinagoods", "country": "China", "model": "Wholesale sourcing directory", "level": 3, "products": [0, 1, 2, 3, 4],
		"factor": 0.66, "minimum": 35, "lead": 20, "quality": 1.02, "reliability": 0.92, "discount": 16,
		"freight": 4.4, "customs": 1.8, "direct": false, "production": 13, "private_label": true},
	{"name": "IndiaMART", "country": "India", "model": "Directory-sourced manufacturer", "level": 3, "products": [0, 1, 2, 3, 4],
		"factor": 0.63, "minimum": 45, "lead": 22, "quality": 1.06, "reliability": 0.95, "discount": 16,
		"freight": 5.2, "customs": 2.1, "direct": false, "production": 15, "private_label": true},
	{"name": "Global Contract Network", "country": "International", "model": "Custom OEM / ODM contracts", "level": 4, "products": [0, 1, 3],
		"factor": 0.48, "minimum": 100, "lead": 30, "quality": 0.90, "reliability": 0.83, "discount": 20,
		"freight": 6, "customs": 2.5, "direct": false, "production": 23, "private_label": true},
]
const SHIPPING := [
	{"name": "Economy", "cost": 3, "days": 4, "reliability": 0.76},
	{"name": "Standard", "cost": 6, "days": 2, "reliability": 0.91},
	{"name": "Express", "cost": 11, "days": 1, "reliability": 0.98},
]
const INBOUND_PER_UNIT := [1.25, 2.0, 3.0]

static func inbound_freight(country: int, supplier: int) -> int:
	var offer: Dictionary = SUPPLIERS[supplier]
	if supplier < INBOUND_PER_UNIT.size():
		return local_cents(country, INBOUND_PER_UNIT[supplier])
	return local_cents(country, float(offer.freight) + float(offer.customs))

static func local_cents(country: int, amount: float) -> int:
	return roundi(amount * SCALE[country] * 100)

static func quote(country: int, product: int, supplier: int) -> int:
	return local_cents(country, PRODUCTS[product].cost * SUPPLIERS[supplier].factor)

static func fee(channel: int, price: int) -> int:
	return roundi(price * FEES[channel] / 100.0)
