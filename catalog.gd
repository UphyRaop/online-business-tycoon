extends RefCounted

const COUNTRIES := ["Malaysia", "United States", "United Kingdom", "Singapore", "Indonesia", "China"]
const CURRENCIES := ["MYR", "USD", "GBP", "SGD", "IDR", "CNY"]
const SCALE := [1.0, 0.25, 0.20, 0.34, 3800.0, 1.7]
const DIFFICULTIES := ["Easy", "Normal", "Hard"]
const CAPITAL := [15000, 5000, 1500]
const OVERHEAD := [4, 6, 9]
const HOSTING := 8
const CHANNELS := ["Marketplace", "Website", "Both channels"]
const FEES := [12, 4]
const TRAFFIC := [1.0, 0.72]
const CATEGORIES := ["Electronics", "Home & Living", "Kitchen", "Fashion", "Beauty", "Fitness", "Automotive", "Baby & Kids", "Pets", "Travel"]
const PRODUCTS := [
	{"id": "obt.kitchen.portable_blender", "name": "Portable Blender", "category": "Kitchen", "cost": 32, "demand": 1.10, "competition": 0.83, "seasonality": [1.05, 1.05, 1.03, 1.02, 1.02, 1.03, 1.03, 1.03, 1.04, 1.08, 1.16, 1.24]},
	{"id": "obt.electronics.wireless_earbuds", "name": "Wireless Earbuds", "category": "Electronics", "cost": 25, "demand": 1.25, "competition": 1.00, "seasonality": [1.05, 1.03, 1.04, 1.02, 1.02, 1.03, 1.05, 1.04, 1.06, 1.10, 1.20, 1.28]},
	{"id": "obt.travel.travel_organizer", "name": "Travel Organizer", "category": "Travel", "cost": 14, "demand": 0.90, "competition": 0.80, "seasonality": [1.03, 1.04, 1.06, 1.10, 1.14, 1.20, 1.22, 1.18, 1.05, 1.02, 1.04, 1.12]},
	{"id": "obt.home_living.desk_lamp", "name": "Desk Lamp", "category": "Home & Living", "cost": 29, "demand": 1.00, "competition": 0.97, "seasonality": [1.12, 1.08, 1.02, 1.00, 1.00, 0.98, 0.98, 0.99, 1.02, 1.08, 1.13, 1.18]},
	{"id": "obt.kitchen.water_bottle", "name": "Water Bottle", "category": "Kitchen", "cost": 12, "demand": 1.15, "competition": 0.77, "seasonality": [1.05, 1.05, 1.03, 1.02, 1.02, 1.03, 1.03, 1.03, 1.04, 1.08, 1.16, 1.24]},
	{"id": "obt.electronics.portable_bluetooth_speaker", "name": "Portable Bluetooth Speaker", "category": "Electronics", "cost": 31, "demand": 1.08, "competition": 0.94, "seasonality": [1.05, 1.03, 1.04, 1.02, 1.02, 1.03, 1.05, 1.04, 1.06, 1.10, 1.20, 1.28]},
	{"id": "obt.electronics.smart_fitness_watch", "name": "Smart Fitness Watch", "category": "Electronics", "cost": 54, "demand": 0.96, "competition": 0.74, "seasonality": [1.05, 1.03, 1.04, 1.02, 1.02, 1.03, 1.05, 1.04, 1.06, 1.10, 1.20, 1.28]},
	{"id": "obt.electronics.usb_c_charging_hub", "name": "USB-C Charging Hub", "category": "Electronics", "cost": 18, "demand": 1.12, "competition": 0.91, "seasonality": [1.05, 1.03, 1.04, 1.02, 1.02, 1.03, 1.05, 1.04, 1.06, 1.10, 1.20, 1.28]},
	{"id": "obt.electronics.noise_cancelling_headphones", "name": "Noise-Cancelling Headphones", "category": "Electronics", "cost": 78, "demand": 0.82, "competition": 1.08, "seasonality": [1.05, 1.03, 1.04, 1.02, 1.02, 1.03, 1.05, 1.04, 1.06, 1.10, 1.20, 1.28]},
	{"id": "obt.electronics.wireless_charging_pad", "name": "Wireless Charging Pad", "category": "Electronics", "cost": 16, "demand": 1.18, "competition": 0.88, "seasonality": [1.05, 1.03, 1.04, 1.02, 1.02, 1.03, 1.05, 1.04, 1.06, 1.10, 1.20, 1.28]},
	{"id": "obt.electronics.compact_action_camera", "name": "Compact Action Camera", "category": "Electronics", "cost": 96, "demand": 0.72, "competition": 1.05, "seasonality": [1.05, 1.03, 1.04, 1.02, 1.02, 1.03, 1.05, 1.04, 1.06, 1.10, 1.20, 1.28]},
	{"id": "obt.electronics.mechanical_keyboard", "name": "Mechanical Keyboard", "category": "Electronics", "cost": 48, "demand": 0.88, "competition": 0.85, "seasonality": [1.05, 1.03, 1.04, 1.02, 1.02, 1.03, 1.05, 1.04, 1.06, 1.10, 1.20, 1.28]},
	{"id": "obt.electronics.portable_ssd_enclosure", "name": "Portable SSD Enclosure", "category": "Electronics", "cost": 27, "demand": 0.92, "competition": 1.02, "seasonality": [1.05, 1.03, 1.04, 1.02, 1.02, 1.03, 1.05, 1.04, 1.06, 1.10, 1.20, 1.28]},
	{"id": "obt.electronics.smart_led_desk_strip", "name": "Smart LED Desk Strip", "category": "Electronics", "cost": 22, "demand": 1.01, "competition": 0.82, "seasonality": [1.05, 1.03, 1.04, 1.02, 1.02, 1.03, 1.05, 1.04, 1.06, 1.10, 1.20, 1.28]},
	{"id": "obt.home_living.memory_foam_cushion", "name": "Memory Foam Cushion", "category": "Home & Living", "cost": 24, "demand": 0.94, "competition": 0.99, "seasonality": [1.12, 1.08, 1.02, 1.00, 1.00, 0.98, 0.98, 0.99, 1.02, 1.08, 1.13, 1.18]},
	{"id": "obt.home_living.foldable_laundry_hamper", "name": "Foldable Laundry Hamper", "category": "Home & Living", "cost": 17, "demand": 0.87, "competition": 0.79, "seasonality": [1.12, 1.08, 1.02, 1.00, 1.00, 0.98, 0.98, 0.99, 1.02, 1.08, 1.13, 1.18]},
	{"id": "obt.home_living.minimal_wall_clock", "name": "Minimal Wall Clock", "category": "Home & Living", "cost": 21, "demand": 0.78, "competition": 0.96, "seasonality": [1.12, 1.08, 1.02, 1.00, 1.00, 0.98, 0.98, 0.99, 1.02, 1.08, 1.13, 1.18]},
	{"id": "obt.home_living.drawer_organizer_set", "name": "Drawer Organizer Set", "category": "Home & Living", "cost": 19, "demand": 1.02, "competition": 0.76, "seasonality": [1.12, 1.08, 1.02, 1.00, 1.00, 0.98, 0.98, 0.99, 1.02, 1.08, 1.13, 1.18]},
	{"id": "obt.home_living.air_purifying_planter", "name": "Air-Purifying Planter", "category": "Home & Living", "cost": 33, "demand": 0.85, "competition": 0.93, "seasonality": [1.12, 1.08, 1.02, 1.00, 1.00, 0.98, 0.98, 0.99, 1.02, 1.08, 1.13, 1.18]},
	{"id": "obt.home_living.cotton_throw_blanket", "name": "Cotton Throw Blanket", "category": "Home & Living", "cost": 38, "demand": 0.91, "competition": 0.73, "seasonality": [1.12, 1.08, 1.02, 1.00, 1.00, 0.98, 0.98, 0.99, 1.02, 1.08, 1.13, 1.18]},
	{"id": "obt.home_living.adjustable_laptop_stand", "name": "Adjustable Laptop Stand", "category": "Home & Living", "cost": 35, "demand": 1.12, "competition": 0.90, "seasonality": [1.12, 1.08, 1.02, 1.00, 1.00, 0.98, 0.98, 0.99, 1.02, 1.08, 1.13, 1.18]},
	{"id": "obt.home_living.compact_shoe_rack", "name": "Compact Shoe Rack", "category": "Home & Living", "cost": 42, "demand": 0.88, "competition": 1.07, "seasonality": [1.12, 1.08, 1.02, 1.00, 1.00, 0.98, 0.98, 0.99, 1.02, 1.08, 1.13, 1.18]},
	{"id": "obt.home_living.reusable_storage_baskets", "name": "Reusable Storage Baskets", "category": "Home & Living", "cost": 27, "demand": 0.97, "competition": 0.87, "seasonality": [1.12, 1.08, 1.02, 1.00, 1.00, 0.98, 0.98, 0.99, 1.02, 1.08, 1.13, 1.18]},
	{"id": "obt.kitchen.digital_kitchen_scale", "name": "Digital Kitchen Scale", "category": "Kitchen", "cost": 19, "demand": 0.96, "competition": 1.04, "seasonality": [1.05, 1.05, 1.03, 1.02, 1.02, 1.03, 1.03, 1.03, 1.04, 1.08, 1.16, 1.24]},
	{"id": "obt.kitchen.silicone_baking_mat_set", "name": "Silicone Baking Mat Set", "category": "Kitchen", "cost": 14, "demand": 1.03, "competition": 0.84, "seasonality": [1.05, 1.05, 1.03, 1.02, 1.02, 1.03, 1.03, 1.03, 1.04, 1.08, 1.16, 1.24]},
	{"id": "obt.kitchen.insulated_lunch_jar", "name": "Insulated Lunch Jar", "category": "Kitchen", "cost": 23, "demand": 1.08, "competition": 1.01, "seasonality": [1.05, 1.05, 1.03, 1.02, 1.02, 1.03, 1.03, 1.03, 1.04, 1.08, 1.16, 1.24]},
	{"id": "obt.kitchen.manual_coffee_grinder", "name": "Manual Coffee Grinder", "category": "Kitchen", "cost": 36, "demand": 0.94, "competition": 0.81, "seasonality": [1.05, 1.05, 1.03, 1.02, 1.02, 1.03, 1.03, 1.03, 1.04, 1.08, 1.16, 1.24]},
	{"id": "obt.kitchen.stackable_glass_containers", "name": "Stackable Glass Containers", "category": "Kitchen", "cost": 31, "demand": 0.99, "competition": 0.98, "seasonality": [1.05, 1.05, 1.03, 1.02, 1.02, 1.03, 1.03, 1.03, 1.04, 1.08, 1.16, 1.24]},
	{"id": "obt.kitchen.bamboo_cutting_board", "name": "Bamboo Cutting Board", "category": "Kitchen", "cost": 26, "demand": 0.87, "competition": 0.78, "seasonality": [1.05, 1.05, 1.03, 1.02, 1.02, 1.03, 1.03, 1.03, 1.04, 1.08, 1.16, 1.24]},
	{"id": "obt.kitchen.electric_milk_frother", "name": "Electric Milk Frother", "category": "Kitchen", "cost": 22, "demand": 1.10, "competition": 0.95, "seasonality": [1.05, 1.05, 1.03, 1.02, 1.02, 1.03, 1.03, 1.03, 1.04, 1.08, 1.16, 1.24]},
	{"id": "obt.kitchen.compact_spice_rack", "name": "Compact Spice Rack", "category": "Kitchen", "cost": 18, "demand": 0.92, "competition": 0.75, "seasonality": [1.05, 1.05, 1.03, 1.02, 1.02, 1.03, 1.03, 1.03, 1.04, 1.08, 1.16, 1.24]},
	{"id": "obt.fashion.canvas_crossbody_bag", "name": "Canvas Crossbody Bag", "category": "Fashion", "cost": 28, "demand": 0.98, "competition": 0.92, "seasonality": [1.10, 1.04, 1.02, 1.00, 1.00, 1.02, 1.05, 1.07, 1.03, 1.05, 1.12, 1.19]},
	{"id": "obt.fashion.everyday_knit_cardigan", "name": "Everyday Knit Cardigan", "category": "Fashion", "cost": 42, "demand": 0.88, "competition": 0.72, "seasonality": [1.10, 1.04, 1.02, 1.00, 1.00, 1.02, 1.05, 1.07, 1.03, 1.05, 1.12, 1.19]},
	{"id": "obt.fashion.minimal_leather_wallet", "name": "Minimal Leather Wallet", "category": "Fashion", "cost": 34, "demand": 0.91, "competition": 0.89, "seasonality": [1.10, 1.04, 1.02, 1.00, 1.00, 1.02, 1.05, 1.07, 1.03, 1.05, 1.12, 1.19]},
	{"id": "obt.fashion.lightweight_travel_scarf", "name": "Lightweight Travel Scarf", "category": "Fashion", "cost": 19, "demand": 0.84, "competition": 1.06, "seasonality": [1.10, 1.04, 1.02, 1.00, 1.00, 1.02, 1.05, 1.07, 1.03, 1.05, 1.12, 1.19]},
	{"id": "obt.fashion.adjustable_baseball_cap", "name": "Adjustable Baseball Cap", "category": "Fashion", "cost": 16, "demand": 1.05, "competition": 0.86, "seasonality": [1.10, 1.04, 1.02, 1.00, 1.00, 1.02, 1.05, 1.07, 1.03, 1.05, 1.12, 1.19]},
	{"id": "obt.fashion.classic_canvas_sneakers", "name": "Classic Canvas Sneakers", "category": "Fashion", "cost": 52, "demand": 1.13, "competition": 1.03, "seasonality": [1.10, 1.04, 1.02, 1.00, 1.00, 1.02, 1.05, 1.07, 1.03, 1.05, 1.12, 1.19]},
	{"id": "obt.fashion.slim_travel_belt", "name": "Slim Travel Belt", "category": "Fashion", "cost": 21, "demand": 0.82, "competition": 0.83, "seasonality": [1.10, 1.04, 1.02, 1.00, 1.00, 1.02, 1.05, 1.07, 1.03, 1.05, 1.12, 1.19]},
	{"id": "obt.fashion.water_resistant_tote", "name": "Water-Resistant Tote", "category": "Fashion", "cost": 33, "demand": 1.01, "competition": 1.00, "seasonality": [1.10, 1.04, 1.02, 1.00, 1.00, 1.02, 1.05, 1.07, 1.03, 1.05, 1.12, 1.19]},
	{"id": "obt.fashion.cotton_lounge_set", "name": "Cotton Lounge Set", "category": "Fashion", "cost": 46, "demand": 0.95, "competition": 0.80, "seasonality": [1.10, 1.04, 1.02, 1.00, 1.00, 1.02, 1.05, 1.07, 1.03, 1.05, 1.12, 1.19]},
	{"id": "obt.fashion.polarized_sunglasses", "name": "Polarized Sunglasses", "category": "Fashion", "cost": 27, "demand": 1.14, "competition": 0.97, "seasonality": [1.10, 1.04, 1.02, 1.00, 1.00, 1.02, 1.05, 1.07, 1.03, 1.05, 1.12, 1.19]},
	{"id": "obt.beauty.facial_cleansing_brush", "name": "Facial Cleansing Brush", "category": "Beauty", "cost": 24, "demand": 1.07, "competition": 0.77, "seasonality": [1.06, 1.04, 1.03, 1.02, 1.02, 1.03, 1.04, 1.04, 1.03, 1.05, 1.12, 1.20]},
	{"id": "obt.beauty.reusable_makeup_pads", "name": "Reusable Makeup Pads", "category": "Beauty", "cost": 11, "demand": 1.12, "competition": 0.94, "seasonality": [1.06, 1.04, 1.03, 1.02, 1.02, 1.03, 1.04, 1.04, 1.03, 1.05, 1.12, 1.20]},
	{"id": "obt.beauty.travel_skincare_case", "name": "Travel Skincare Case", "category": "Beauty", "cost": 18, "demand": 1.03, "competition": 0.74, "seasonality": [1.06, 1.04, 1.03, 1.02, 1.02, 1.03, 1.04, 1.04, 1.03, 1.05, 1.12, 1.20]},
	{"id": "obt.beauty.ceramic_hair_styling_brush", "name": "Ceramic Hair Styling Brush", "category": "Beauty", "cost": 37, "demand": 0.92, "competition": 0.91, "seasonality": [1.06, 1.04, 1.03, 1.02, 1.02, 1.03, 1.04, 1.04, 1.03, 1.05, 1.12, 1.20]},
	{"id": "obt.beauty.led_vanity_mirror", "name": "LED Vanity Mirror", "category": "Beauty", "cost": 43, "demand": 0.98, "competition": 1.08, "seasonality": [1.06, 1.04, 1.03, 1.02, 1.02, 1.03, 1.04, 1.04, 1.03, 1.05, 1.12, 1.20]},
	{"id": "obt.beauty.nail_care_toolkit", "name": "Nail Care Toolkit", "category": "Beauty", "cost": 16, "demand": 0.90, "competition": 0.88, "seasonality": [1.06, 1.04, 1.03, 1.02, 1.02, 1.03, 1.04, 1.04, 1.03, 1.05, 1.12, 1.20]},
	{"id": "obt.beauty.silk_sleep_mask", "name": "Silk Sleep Mask", "category": "Beauty", "cost": 14, "demand": 1.10, "competition": 1.05, "seasonality": [1.06, 1.04, 1.03, 1.02, 1.02, 1.03, 1.04, 1.04, 1.03, 1.05, 1.12, 1.20]},
	{"id": "obt.beauty.refillable_perfume_atomizer", "name": "Refillable Perfume Atomizer", "category": "Beauty", "cost": 12, "demand": 1.02, "competition": 0.85, "seasonality": [1.06, 1.04, 1.03, 1.02, 1.02, 1.03, 1.04, 1.04, 1.03, 1.05, 1.12, 1.20]},
	{"id": "obt.beauty.cooling_eye_roller", "name": "Cooling Eye Roller", "category": "Beauty", "cost": 17, "demand": 0.94, "competition": 1.02, "seasonality": [1.06, 1.04, 1.03, 1.02, 1.02, 1.03, 1.04, 1.04, 1.03, 1.05, 1.12, 1.20]},
	{"id": "obt.beauty.makeup_brush_organizer", "name": "Makeup Brush Organizer", "category": "Beauty", "cost": 22, "demand": 0.99, "competition": 0.82, "seasonality": [1.06, 1.04, 1.03, 1.02, 1.02, 1.03, 1.04, 1.04, 1.03, 1.05, 1.12, 1.20]},
	{"id": "obt.fitness.adjustable_resistance_bands", "name": "Adjustable Resistance Bands", "category": "Fitness", "cost": 21, "demand": 1.19, "competition": 0.99, "seasonality": [1.12, 1.18, 1.14, 1.08, 1.04, 1.02, 1.00, 1.00, 1.03, 1.05, 1.04, 1.07]},
	{"id": "obt.fitness.compact_yoga_mat", "name": "Compact Yoga Mat", "category": "Fitness", "cost": 36, "demand": 1.08, "competition": 0.79, "seasonality": [1.12, 1.18, 1.14, 1.08, 1.04, 1.02, 1.00, 1.00, 1.03, 1.05, 1.04, 1.07]},
	{"id": "obt.fitness.foam_massage_roller", "name": "Foam Massage Roller", "category": "Fitness", "cost": 29, "demand": 0.96, "competition": 0.96, "seasonality": [1.12, 1.18, 1.14, 1.08, 1.04, 1.02, 1.00, 1.00, 1.03, 1.05, 1.04, 1.07]},
	{"id": "obt.fitness.digital_jump_rope", "name": "Digital Jump Rope", "category": "Fitness", "cost": 18, "demand": 1.04, "competition": 0.76, "seasonality": [1.12, 1.18, 1.14, 1.08, 1.04, 1.02, 1.00, 1.00, 1.03, 1.05, 1.04, 1.07]},
	{"id": "obt.fitness.grip_strength_trainer", "name": "Grip Strength Trainer", "category": "Fitness", "cost": 13, "demand": 0.91, "competition": 0.93, "seasonality": [1.12, 1.18, 1.14, 1.08, 1.04, 1.02, 1.00, 1.00, 1.03, 1.05, 1.04, 1.07]},
	{"id": "obt.fitness.running_waist_pack", "name": "Running Waist Pack", "category": "Fitness", "cost": 24, "demand": 1.03, "competition": 0.73, "seasonality": [1.12, 1.18, 1.14, 1.08, 1.04, 1.02, 1.00, 1.00, 1.03, 1.05, 1.04, 1.07]},
	{"id": "obt.fitness.insulated_shaker_bottle", "name": "Insulated Shaker Bottle", "category": "Fitness", "cost": 16, "demand": 1.13, "competition": 0.90, "seasonality": [1.12, 1.18, 1.14, 1.08, 1.04, 1.02, 1.00, 1.00, 1.03, 1.05, 1.04, 1.07]},
	{"id": "obt.fitness.balance_training_pad", "name": "Balance Training Pad", "category": "Fitness", "cost": 32, "demand": 0.90, "competition": 1.07, "seasonality": [1.12, 1.18, 1.14, 1.08, 1.04, 1.02, 1.00, 1.00, 1.03, 1.05, 1.04, 1.07]},
	{"id": "obt.fitness.wrist_support_pair", "name": "Wrist Support Pair", "category": "Fitness", "cost": 14, "demand": 0.87, "competition": 0.87, "seasonality": [1.12, 1.18, 1.14, 1.08, 1.04, 1.02, 1.00, 1.00, 1.03, 1.05, 1.04, 1.07]},
	{"id": "obt.fitness.portable_workout_timer", "name": "Portable Workout Timer", "category": "Fitness", "cost": 27, "demand": 0.83, "competition": 1.04, "seasonality": [1.12, 1.18, 1.14, 1.08, 1.04, 1.02, 1.00, 1.00, 1.03, 1.05, 1.04, 1.07]},
	{"id": "obt.automotive.magnetic_phone_mount", "name": "Magnetic Phone Mount", "category": "Automotive", "cost": 17, "demand": 1.14, "competition": 0.84, "seasonality": [1.02, 1.02, 1.05, 1.07, 1.09, 1.08, 1.05, 1.03, 1.02, 1.02, 1.01, 1.03]},
	{"id": "obt.automotive.emergency_roadside_kit", "name": "Emergency Roadside Kit", "category": "Automotive", "cost": 48, "demand": 0.78, "competition": 1.01, "seasonality": [1.02, 1.02, 1.05, 1.07, 1.09, 1.08, 1.05, 1.03, 1.02, 1.02, 1.01, 1.03]},
	{"id": "obt.automotive.trunk_organizer", "name": "Trunk Organizer", "category": "Automotive", "cost": 31, "demand": 0.97, "competition": 0.81, "seasonality": [1.02, 1.02, 1.05, 1.07, 1.09, 1.08, 1.05, 1.03, 1.02, 1.02, 1.01, 1.03]},
	{"id": "obt.automotive.microfiber_detailing_set", "name": "Microfiber Detailing Set", "category": "Automotive", "cost": 22, "demand": 1.02, "competition": 0.98, "seasonality": [1.02, 1.02, 1.05, 1.07, 1.09, 1.08, 1.05, 1.03, 1.02, 1.02, 1.01, 1.03]},
	{"id": "obt.automotive.tire_pressure_gauge", "name": "Tire Pressure Gauge", "category": "Automotive", "cost": 16, "demand": 0.81, "competition": 0.78, "seasonality": [1.02, 1.02, 1.05, 1.07, 1.09, 1.08, 1.05, 1.03, 1.02, 1.02, 1.01, 1.03]},
	{"id": "obt.automotive.seat_gap_organizer", "name": "Seat Gap Organizer", "category": "Automotive", "cost": 19, "demand": 0.90, "competition": 0.95, "seasonality": [1.02, 1.02, 1.05, 1.07, 1.09, 1.08, 1.05, 1.03, 1.02, 1.02, 1.01, 1.03]},
	{"id": "obt.automotive.portable_tire_inflator", "name": "Portable Tire Inflator", "category": "Automotive", "cost": 68, "demand": 0.89, "competition": 0.75, "seasonality": [1.02, 1.02, 1.05, 1.07, 1.09, 1.08, 1.05, 1.03, 1.02, 1.02, 1.01, 1.03]},
	{"id": "obt.automotive.rechargeable_work_light", "name": "Rechargeable Work Light", "category": "Automotive", "cost": 34, "demand": 0.84, "competition": 0.92, "seasonality": [1.02, 1.02, 1.05, 1.07, 1.09, 1.08, 1.05, 1.03, 1.02, 1.02, 1.01, 1.03]},
	{"id": "obt.automotive.compact_car_vacuum", "name": "Compact Car Vacuum", "category": "Automotive", "cost": 52, "demand": 0.99, "competition": 0.72, "seasonality": [1.02, 1.02, 1.05, 1.07, 1.09, 1.08, 1.05, 1.03, 1.02, 1.02, 1.01, 1.03]},
	{"id": "obt.automotive.reusable_sunshade_pair", "name": "Reusable Sunshade Pair", "category": "Automotive", "cost": 25, "demand": 0.93, "competition": 0.89, "seasonality": [1.02, 1.02, 1.05, 1.07, 1.09, 1.08, 1.05, 1.03, 1.02, 1.02, 1.01, 1.03]},
	{"id": "obt.baby_kids.silicone_feeding_set", "name": "Silicone Feeding Set", "category": "Baby & Kids", "cost": 22, "demand": 1.08, "competition": 1.06, "seasonality": [1.10, 1.07, 1.04, 1.02, 1.02, 1.03, 1.06, 1.08, 1.05, 1.07, 1.14, 1.20]},
	{"id": "obt.baby_kids.soft_activity_play_mat", "name": "Soft Activity Play Mat", "category": "Baby & Kids", "cost": 58, "demand": 0.92, "competition": 0.86, "seasonality": [1.10, 1.07, 1.04, 1.02, 1.02, 1.03, 1.06, 1.08, 1.05, 1.07, 1.14, 1.20]},
	{"id": "obt.baby_kids.foldable_stroller_organizer", "name": "Foldable Stroller Organizer", "category": "Baby & Kids", "cost": 27, "demand": 0.97, "competition": 1.03, "seasonality": [1.10, 1.07, 1.04, 1.02, 1.02, 1.03, 1.06, 1.08, 1.05, 1.07, 1.14, 1.20]},
	{"id": "obt.baby_kids.waterproof_changing_pad", "name": "Waterproof Changing Pad", "category": "Baby & Kids", "cost": 19, "demand": 1.02, "competition": 0.83, "seasonality": [1.10, 1.07, 1.04, 1.02, 1.02, 1.03, 1.06, 1.08, 1.05, 1.07, 1.14, 1.20]},
	{"id": "obt.baby_kids.wooden_shape_puzzle", "name": "Wooden Shape Puzzle", "category": "Baby & Kids", "cost": 24, "demand": 0.88, "competition": 1.00, "seasonality": [1.10, 1.07, 1.04, 1.02, 1.02, 1.03, 1.06, 1.08, 1.05, 1.07, 1.14, 1.20]},
	{"id": "obt.baby_kids.adjustable_high_chair_cushion", "name": "Adjustable High Chair Cushion", "category": "Baby & Kids", "cost": 31, "demand": 0.85, "competition": 0.80, "seasonality": [1.10, 1.07, 1.04, 1.02, 1.02, 1.03, 1.06, 1.08, 1.05, 1.07, 1.14, 1.20]},
	{"id": "obt.baby_kids.gentle_night_light", "name": "Gentle Night Light", "category": "Baby & Kids", "cost": 18, "demand": 1.12, "competition": 0.97, "seasonality": [1.10, 1.07, 1.04, 1.02, 1.02, 1.03, 1.06, 1.08, 1.05, 1.07, 1.14, 1.20]},
	{"id": "obt.baby_kids.reusable_snack_pouch_set", "name": "Reusable Snack Pouch Set", "category": "Baby & Kids", "cost": 17, "demand": 1.05, "competition": 0.77, "seasonality": [1.10, 1.07, 1.04, 1.02, 1.02, 1.03, 1.06, 1.08, 1.05, 1.07, 1.14, 1.20]},
	{"id": "obt.baby_kids.toddler_travel_tray", "name": "Toddler Travel Tray", "category": "Baby & Kids", "cost": 29, "demand": 0.96, "competition": 0.94, "seasonality": [1.10, 1.07, 1.04, 1.02, 1.02, 1.03, 1.06, 1.08, 1.05, 1.07, 1.14, 1.20]},
	{"id": "obt.baby_kids.plush_nap_blanket", "name": "Plush Nap Blanket", "category": "Baby & Kids", "cost": 26, "demand": 1.01, "competition": 0.74, "seasonality": [1.10, 1.07, 1.04, 1.02, 1.02, 1.03, 1.06, 1.08, 1.05, 1.07, 1.14, 1.20]},
	{"id": "obt.pets.slow_feed_pet_bowl", "name": "Slow-Feed Pet Bowl", "category": "Pets", "cost": 21, "demand": 1.02, "competition": 0.91, "seasonality": [1.03, 1.02, 1.03, 1.04, 1.05, 1.05, 1.04, 1.04, 1.04, 1.05, 1.08, 1.10]},
	{"id": "obt.pets.washable_pet_bed", "name": "Washable Pet Bed", "category": "Pets", "cost": 49, "demand": 0.94, "competition": 1.08, "seasonality": [1.03, 1.02, 1.03, 1.04, 1.05, 1.05, 1.04, 1.04, 1.04, 1.05, 1.08, 1.10]},
	{"id": "obt.pets.reflective_walking_harness", "name": "Reflective Walking Harness", "category": "Pets", "cost": 26, "demand": 0.98, "competition": 0.88, "seasonality": [1.03, 1.02, 1.03, 1.04, 1.05, 1.05, 1.04, 1.04, 1.04, 1.05, 1.08, 1.10]},
	{"id": "obt.pets.treat_training_pouch", "name": "Treat Training Pouch", "category": "Pets", "cost": 18, "demand": 1.09, "competition": 1.05, "seasonality": [1.03, 1.02, 1.03, 1.04, 1.05, 1.05, 1.04, 1.04, 1.04, 1.05, 1.08, 1.10]},
	{"id": "obt.pets.interactive_feather_toy", "name": "Interactive Feather Toy", "category": "Pets", "cost": 13, "demand": 1.14, "competition": 0.85, "seasonality": [1.03, 1.02, 1.03, 1.04, 1.05, 1.05, 1.04, 1.04, 1.04, 1.05, 1.08, 1.10]},
	{"id": "obt.pets.pet_hair_grooming_glove", "name": "Pet Hair Grooming Glove", "category": "Pets", "cost": 11, "demand": 0.95, "competition": 1.02, "seasonality": [1.03, 1.02, 1.03, 1.04, 1.05, 1.05, 1.04, 1.04, 1.04, 1.05, 1.08, 1.10]},
	{"id": "obt.pets.collapsible_travel_carrier", "name": "Collapsible Travel Carrier", "category": "Pets", "cost": 54, "demand": 0.87, "competition": 0.82, "seasonality": [1.03, 1.02, 1.03, 1.04, 1.05, 1.05, 1.04, 1.04, 1.04, 1.05, 1.08, 1.10]},
	{"id": "obt.pets.leakproof_water_dispenser", "name": "Leakproof Water Dispenser", "category": "Pets", "cost": 24, "demand": 1.00, "competition": 0.99, "seasonality": [1.03, 1.02, 1.03, 1.04, 1.05, 1.05, 1.04, 1.04, 1.04, 1.05, 1.08, 1.10]},
	{"id": "obt.pets.snuffle_enrichment_mat", "name": "Snuffle Enrichment Mat", "category": "Pets", "cost": 28, "demand": 1.03, "competition": 0.79, "seasonality": [1.03, 1.02, 1.03, 1.04, 1.05, 1.05, 1.04, 1.04, 1.04, 1.05, 1.08, 1.10]},
	{"id": "obt.pets.adjustable_cat_window_perch", "name": "Adjustable Cat Window Perch", "category": "Pets", "cost": 37, "demand": 0.91, "competition": 0.96, "seasonality": [1.03, 1.02, 1.03, 1.04, 1.05, 1.05, 1.04, 1.04, 1.04, 1.05, 1.08, 1.10]},
	{"id": "obt.travel.packing_cube_set", "name": "Packing Cube Set", "category": "Travel", "cost": 22, "demand": 1.12, "competition": 0.76, "seasonality": [1.03, 1.04, 1.06, 1.10, 1.14, 1.20, 1.22, 1.18, 1.05, 1.02, 1.04, 1.12]},
	{"id": "obt.travel.compact_neck_pillow", "name": "Compact Neck Pillow", "category": "Travel", "cost": 25, "demand": 1.04, "competition": 0.93, "seasonality": [1.03, 1.04, 1.06, 1.10, 1.14, 1.20, 1.22, 1.18, 1.05, 1.02, 1.04, 1.12]},
	{"id": "obt.travel.digital_luggage_scale", "name": "Digital Luggage Scale", "category": "Travel", "cost": 16, "demand": 0.96, "competition": 0.73, "seasonality": [1.03, 1.04, 1.06, 1.10, 1.14, 1.20, 1.22, 1.18, 1.05, 1.02, 1.04, 1.12]},
	{"id": "obt.travel.rfid_passport_wallet", "name": "RFID Passport Wallet", "category": "Travel", "cost": 19, "demand": 0.89, "competition": 0.90, "seasonality": [1.03, 1.04, 1.06, 1.10, 1.14, 1.20, 1.22, 1.18, 1.05, 1.02, 1.04, 1.12]},
	{"id": "obt.travel.foldable_daypack", "name": "Foldable Daypack", "category": "Travel", "cost": 33, "demand": 1.09, "competition": 1.07, "seasonality": [1.03, 1.04, 1.06, 1.10, 1.14, 1.20, 1.22, 1.18, 1.05, 1.02, 1.04, 1.12]},
	{"id": "obt.travel.universal_adapter_case", "name": "Universal Adapter Case", "category": "Travel", "cost": 28, "demand": 0.93, "competition": 0.87, "seasonality": [1.03, 1.04, 1.06, 1.10, 1.14, 1.20, 1.22, 1.18, 1.05, 1.02, 1.04, 1.12]},
	{"id": "obt.travel.compression_shoe_bags", "name": "Compression Shoe Bags", "category": "Travel", "cost": 13, "demand": 1.00, "competition": 1.04, "seasonality": [1.03, 1.04, 1.06, 1.10, 1.14, 1.20, 1.22, 1.18, 1.05, 1.02, 1.04, 1.12]},
	{"id": "obt.travel.leakproof_toiletry_bottles", "name": "Leakproof Toiletry Bottles", "category": "Travel", "cost": 12, "demand": 1.06, "competition": 0.84, "seasonality": [1.03, 1.04, 1.06, 1.10, 1.14, 1.20, 1.22, 1.18, 1.05, 1.02, 1.04, 1.12]},
	{"id": "obt.travel.expandable_cabin_duffel", "name": "Expandable Cabin Duffel", "category": "Travel", "cost": 61, "demand": 0.88, "competition": 1.01, "seasonality": [1.03, 1.04, 1.06, 1.10, 1.14, 1.20, 1.22, 1.18, 1.05, 1.02, 1.04, 1.12]}
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
# Keep the original supplier rows and positions as an immutable legacy lookup:
# historical purchase orders, quotations and fulfillment lines contain these indices.
# Only SUPPLIER_SELECTION_INDICES are offered for new sourcing.
const SUPPLIER_SELECTION_INDICES := [3, 4, 7, 8, 9, 12, 13, 14, 17]
const SUPPLIER_ID_BY_LEGACY_INDEX := [
	"legacy_value_supply", "legacy_reliable_direct", "legacy_premium_partners",
	"aliexpress", "cjdropshipping", "legacy_eprolo", "legacy_dhgate",
	"alibaba", "1688", "taobao", "legacy_banggood", "legacy_yiwugo",
	"made_in_china", "global_sources", "hypersku", "legacy_chinagoods",
	"legacy_indiamart", "global_enterprise_network",
]
const DEFAULT_SUPPLIER := 3
const SHIPPING := [
	{"name": "Economy", "cost": 3, "days": 4, "reliability": 0.76},
	{"name": "Standard", "cost": 6, "days": 2, "reliability": 0.91},
	{"name": "Express", "cost": 11, "days": 1, "reliability": 0.98},
]
const INBOUND_PER_UNIT := [1.25, 2.0, 3.0]
const SUPPLIER_THRESHOLDS_USD := [0, 10000, 100000, 1000000]
# Simulated caps by legacy supplier index; historic indices remain unchanged.
const SUPPLIER_MAX_ORDER := [0, 0, 0, 500, 2500, 0, 0, 50000, 100000, 20000, 0, 0, 250000, 200000, 10000, 0, 0, 1000000]

static func inbound_freight(country: int, supplier: int) -> int:
	return local_cents(country, INBOUND_PER_UNIT[supplier]) if supplier < INBOUND_PER_UNIT.size() else local_cents(country, SUPPLIERS[supplier].freight + SUPPLIERS[supplier].customs)

static func supplier_available_for_sourcing(supplier: int) -> bool:
	return supplier in SUPPLIER_SELECTION_INDICES

static func supplier_id(supplier: int) -> String:
	return SUPPLIER_ID_BY_LEGACY_INDEX[supplier] if supplier in range(SUPPLIER_ID_BY_LEGACY_INDEX.size()) else ""

static func supplier_index(stable_id: String) -> int:
	return SUPPLIER_ID_BY_LEGACY_INDEX.find(stable_id)

static func local_cents(country: int, amount: float) -> int:
	return roundi(amount * SCALE[country] * 100)

static func product_id(product: int) -> String:
	return str(PRODUCTS[product].id) if product in range(PRODUCTS.size()) else ""

static func product_index(stable_id: String) -> int:
	for i in PRODUCTS.size():
		if str(PRODUCTS[i].id) == stable_id: return i
	return -1

static func product_seasonality(product: int, day: int) -> float:
	if product not in range(PRODUCTS.size()): return 1.0
	var date := Time.get_datetime_dict_from_unix_time(1767225600 + (day - 1) * 86400)
	var factors: Array = PRODUCTS[product].seasonality
	return float(factors[date.month - 1]) if factors.size() == 12 else 1.0

static func quote(country: int, product: int, supplier: int) -> int:
	return local_cents(country, PRODUCTS[product].cost * SUPPLIERS[supplier].factor)

static func fee(channel: int, price: int) -> int:
	return roundi(price * FEES[channel] / 100.0)
