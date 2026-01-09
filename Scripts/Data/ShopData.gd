# SCRIPT: ShopData.gd
# Centralized weapon and shop data
# LOCATION: res://Scripts/Data/ShopData.gd

class_name ShopData
extends RefCounted

# ============================================
# WEAPON TYPES
# ============================================
enum WeaponType {
	MELEE,
	STAFF
}

# ============================================
# MELEE WEAPONS DATA
# ============================================
const MELEE_WEAPONS = {
	"katana": {
		"name": "Katana",
		"scene": "res://Scenes/Weapons/Katana/Katana.tscn",
		"price": 10,
		"description": "Fast slashing blade",
		"icon_color": Color(0.8, 0.8, 0.9)
	},
	"axe": {
		"name": "Executioner's Axe",
		"scene": "res://Scenes/Weapons/ExecutionersAxe/ExecutionersAxe.tscn",
		"price": 15,
		"description": "Heavy cleaving damage",
		"icon_color": Color(0.6, 0.4, 0.3)
	},
	"rapier": {
		"name": "Rapier",
		"scene": "res://Scenes/Weapons/Rapier/Rapier.tscn",
		"price": 12,
		"description": "Quick thrust attacks",
		"icon_color": Color(0.7, 0.7, 0.8)
	},
	"warhammer": {
		"name": "Warhammer",
		"scene": "res://Scenes/Weapons/Warhammer/Warhammer.tscn",
		"price": 18,
		"description": "Devastating slam attacks",
		"icon_color": Color(0.5, 0.5, 0.5)
	},
	"scythe": {
		"name": "Scythe",
		"scene": "res://Scenes/Weapons/Scythe/Scythe.tscn",
		"price": 20,
		"description": "Wide sweeping arcs",
		"icon_color": Color(0.3, 0.3, 0.4)
	},
	"spear": {
		"name": "Spear",
		"scene": "res://Scenes/Weapons/Spear/Spear.tscn",
		"price": 16,
		"description": "Long reach piercing",
		"icon_color": Color(0.6, 0.5, 0.3)
	},
	"dagger": {
		"name": "Dagger",
		"scene": "res://Scenes/Weapons/Dagger/Dagger.tscn",
		"price": 8,
		"description": "Fast close-range strikes",
		"icon_color": Color(0.4, 0.4, 0.5)
	}
}

# ============================================
# STAFF WEAPONS DATA
# ============================================
const STAFF_WEAPONS = {
	"lightning_staff": {
		"name": "Lightning Staff",
		"scene": "res://Scenes/Weapons/LightningStaff/LightningStaff.tscn",
		"price": 10,
		"description": "Chain lightning magic",
		"icon_color": Color(0.8, 0.9, 1.0)
	},
	"inferno_staff": {
		"name": "Inferno Staff",
		"scene": "res://Scenes/Weapons/InfernoStaff/InfernoStaff.tscn",
		"price": 12,
		"description": "Burning fire magic",
		"icon_color": Color(1.0, 0.4, 0.1)
	},
	"frost_staff": {
		"name": "Frost Staff",
		"scene": "res://Scenes/Weapons/FrostStaff/FrostStaff.tscn",
		"price": 11,
		"description": "Freezing ice magic",
		"icon_color": Color(0.5, 0.8, 1.0)
	},
	"void_staff": {
		"name": "Void Staff",
		"scene": "res://Scenes/Weapons/VoidStaff/VoidStaff.tscn",
		"price": 16,
		"description": "Dark void energy",
		"icon_color": Color(0.4, 0.1, 0.6)
	},
	"necro_staff": {
		"name": "Necro Staff",
		"scene": "res://Scenes/Weapons/NecroStaff/NecroStaff.tscn",
		"price": 22,
		"description": "Summon undead minions",
		"icon_color": Color(0.3, 0.8, 0.4)
	},
	"earth_staff": {
		"name": "Earth Staff",
		"scene": "res://Scenes/Weapons/EarthStaff/EarthStaff.tscn",
		"price": 13,
		"description": "Rock and earth magic",
		"icon_color": Color(0.6, 0.4, 0.2)
	},
	"holy_staff": {
		"name": "Holy Staff",
		"scene": "res://Scenes/Weapons/HolyStaff/HolyStaff.tscn",
		"price": 15,
		"description": "Divine healing light",
		"icon_color": Color(1.0, 0.95, 0.7)
	}
}

# ============================================
# HEALER PRICES
# ============================================
const FREE_HEAL_PERCENT := 0.30
const FULL_HEAL_PRICE := 50

# ============================================
# HELPER FUNCTIONS
# ============================================
static func get_weapon_data(weapon_id: String) -> Dictionary:
	if MELEE_WEAPONS.has(weapon_id):
		var data = MELEE_WEAPONS[weapon_id].duplicate()
		data["type"] = WeaponType.MELEE
		return data
	elif STAFF_WEAPONS.has(weapon_id):
		var data = STAFF_WEAPONS[weapon_id].duplicate()
		data["type"] = WeaponType.STAFF
		return data
	return {}

static func get_all_melee_weapons() -> Dictionary:
	return MELEE_WEAPONS.duplicate()

static func get_all_staff_weapons() -> Dictionary:
	return STAFF_WEAPONS.duplicate()

static func get_all_weapons() -> Dictionary:
	var all = {}
	for id in MELEE_WEAPONS:
		all[id] = MELEE_WEAPONS[id].duplicate()
		all[id]["type"] = WeaponType.MELEE
	for id in STAFF_WEAPONS:
		all[id] = STAFF_WEAPONS[id].duplicate()
		all[id]["type"] = WeaponType.STAFF
	return all
