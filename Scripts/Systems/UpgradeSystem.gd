# SCRIPT: UpgradeSystem.gd
# ATTACH TO: Nothing - this is an autoload singleton
# LOCATION: res://Scripts/Systems/UpgradeSystem.gd

class_name UpgradeSystem
extends Node

# ============================================
# UPGRADE LOADING
# ============================================
# Path to upgrade resources
const UPGRADES_PATH = "res://Resources/Upgrades/"

# All loaded upgrades
var all_upgrades: Array[UpgradeResource] = []

# Legacy upgrades (kept for backwards compatibility, will be converted to resources)
var _legacy_upgrades: Array = [
	{
		"id": "health_boost_small",
		"name": "Health Boost",
		"description": "+20 Max Health",
		"icon_color": Color.RED,
		"type": "stat",
		"stat_type": "max_health",
		"value": 20.0,
		"weight": 1.0,
		"rarity": "common"
	},
	{
		"id": "health_boost_large",
		"name": "Vitality",
		"description": "+50 Max Health",
		"icon_color": Color.DARK_RED,
		"type": "stat",
		"stat_type": "max_health",
		"value": 50.0,
		"weight": 0.5,
		"rarity": "uncommon"
	},
	{
		"id": "heal_full",
		"name": "Full Heal",
		"description": "Restore all health",
		"icon_color": Color.PINK,
		"type": "instant",
		"stat_type": "max_health",
		"value": 0,
		"weight": 0.8,
		"rarity": "common",
		"can_repeat": true
	},
	{
		"id": "melee_damage_small",
		"name": "Sharp Blade",
		"description": "+25% Melee Damage",
		"icon_color": Color.ORANGE,
		"type": "stat",
		"stat_type": "melee_damage",
		"value": 0.25,
		"weight": 1.0,
		"rarity": "common"
	},
	{
		"id": "magic_damage_small",
		"name": "Arcane Power",
		"description": "+25% Magic Damage",
		"icon_color": Color.CYAN,
		"type": "stat",
		"stat_type": "magic_damage",
		"value": 0.25,
		"weight": 1.0,
		"rarity": "common"
	},
	{
		"id": "all_damage",
		"name": "Chaos Fury",
		"description": "+15% All Damage",
		"icon_color": Color.PURPLE,
		"type": "stat",
		"stat_type": "all_damage",
		"value": 0.15,
		"weight": 0.6,
		"rarity": "rare"
	},
	{
		"id": "move_speed_small",
		"name": "Swift Boots",
		"description": "+20% Move Speed",
		"icon_color": Color.GREEN,
		"type": "stat",
		"stat_type": "move_speed",
		"value": 0.2,
		"weight": 1.0,
		"rarity": "common",
		"is_percentage": true
	},
	{
		"id": "attack_speed",
		"name": "Berserker",
		"description": "+30% Attack Speed",
		"icon_color": Color.YELLOW,
		"type": "stat",
		"stat_type": "attack_speed",
		"value": 0.3,
		"weight": 0.8,
		"rarity": "uncommon"
	},
	{
		"id": "extra_projectile",
		"name": "Multi-Shot",
		"description": "+1 Projectile per cast",
		"icon_color": Color.BLUE,
		"type": "special",
		"stat_type": "multi_shot",
		"value": 1,
		"weight": 0.4,
		"rarity": "rare"
	},
	{
		"id": "vampirism",
		"name": "Vampirism",
		"description": "Heal 2 HP per kill",
		"icon_color": Color.DARK_RED,
		"type": "special",
		"stat_type": "lifesteal",
		"value": 2,
		"weight": 0.3,
		"rarity": "rare"
	},
	{
		"id": "crit_chance_small",
		"name": "Lucky Strike",
		"description": "+10% Critical Hit Chance",
		"icon_color": Color.ORANGE_RED,
		"type": "stat",
		"stat_type": "crit_chance",
		"value": 0.1,
		"weight": 0.7,
		"rarity": "uncommon"
	},
	{
		"id": "crit_chance_large",
		"name": "Assassin's Eye",
		"description": "+20% Critical Hit Chance",
		"icon_color": Color.CRIMSON,
		"type": "stat",
		"stat_type": "crit_chance",
		"value": 0.2,
		"weight": 0.4,
		"rarity": "rare"
	},
	{
		"id": "crit_damage",
		"name": "Deadly Precision",
		"description": "+50% Critical Damage",
		"icon_color": Color.GOLD,
		"type": "stat",
		"stat_type": "crit_damage",
		"value": 0.5,
		"weight": 0.5,
		"rarity": "rare"
	}
]

# Track picked upgrades to avoid duplicates in same run
var picked_upgrades: Dictionary = {}  # id -> stack count
var upgrades_per_wave: int = 3

func _ready():
	_load_upgrades()

func _load_upgrades():
	# First, try to load from resource files
	var dir = DirAccess.open(UPGRADES_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var upgrade = load(UPGRADES_PATH + file_name) as UpgradeResource
				if upgrade:
					all_upgrades.append(upgrade)
			file_name = dir.get_next()
		dir.list_dir_end()

	# If no resources found, convert legacy upgrades
	if all_upgrades.is_empty():
		_convert_legacy_upgrades()

func _convert_legacy_upgrades():
	for data in _legacy_upgrades:
		var upgrade = UpgradeResource.new()
		upgrade.id = data.get("id", "")
		upgrade.upgrade_name = data.get("name", "")
		upgrade.description = data.get("description", "")
		upgrade.icon_color = data.get("icon_color", Color.WHITE)
		upgrade.value = data.get("value", 0.0)
		upgrade.weight = data.get("weight", 1.0)
		upgrade.can_repeat = data.get("can_repeat", false)
		upgrade.is_percentage = data.get("is_percentage", false)

		# Convert type
		match data.get("type", "stat"):
			"stat":
				upgrade.upgrade_type = UpgradeResource.UpgradeType.STAT
			"instant":
				upgrade.upgrade_type = UpgradeResource.UpgradeType.INSTANT
			"special":
				upgrade.upgrade_type = UpgradeResource.UpgradeType.SPECIAL

		# Convert stat type
		match data.get("stat_type", "max_health"):
			"max_health":
				upgrade.stat_type = UpgradeResource.StatType.MAX_HEALTH
			"melee_damage":
				upgrade.stat_type = UpgradeResource.StatType.MELEE_DAMAGE
			"magic_damage":
				upgrade.stat_type = UpgradeResource.StatType.MAGIC_DAMAGE
			"all_damage":
				upgrade.stat_type = UpgradeResource.StatType.ALL_DAMAGE
			"move_speed":
				upgrade.stat_type = UpgradeResource.StatType.MOVE_SPEED
			"attack_speed":
				upgrade.stat_type = UpgradeResource.StatType.ATTACK_SPEED
			"crit_chance":
				upgrade.stat_type = UpgradeResource.StatType.CRIT_CHANCE
			"crit_damage":
				upgrade.stat_type = UpgradeResource.StatType.CRIT_DAMAGE
			"lifesteal":
				upgrade.stat_type = UpgradeResource.StatType.LIFESTEAL
			"multi_shot":
				upgrade.stat_type = UpgradeResource.StatType.MULTI_SHOT

		# Convert rarity
		match data.get("rarity", "common"):
			"common":
				upgrade.rarity = UpgradeResource.Rarity.COMMON
			"uncommon":
				upgrade.rarity = UpgradeResource.Rarity.UNCOMMON
			"rare":
				upgrade.rarity = UpgradeResource.Rarity.RARE
			"legendary":
				upgrade.rarity = UpgradeResource.Rarity.LEGENDARY

		all_upgrades.append(upgrade)

# ============================================
# OPTIMIZED WEIGHTED RANDOM SELECTION - O(n)
# ============================================
func get_random_upgrades(count: int = 3) -> Array:
	var available: Array[UpgradeResource] = []

	# Filter available upgrades
	for upgrade in all_upgrades:
		if _is_upgrade_available(upgrade):
			available.append(upgrade)

	# Reset if not enough
	if available.size() < count:
		picked_upgrades.clear()
		available.clear()
		for upgrade in all_upgrades:
			available.append(upgrade)

	# O(n) weighted selection using prefix sums
	return _weighted_select(available, count)

func _is_upgrade_available(upgrade: UpgradeResource) -> bool:
	var current_stacks = picked_upgrades.get(upgrade.id, 0)

	# Instant upgrades can always repeat
	if upgrade.upgrade_type == UpgradeResource.UpgradeType.INSTANT:
		return true

	# Check if can repeat and stack limit
	if upgrade.can_repeat:
		return current_stacks < upgrade.max_stacks

	# Non-repeatable: only available if not picked
	return current_stacks == 0

func _weighted_select(available: Array, count: int) -> Array:
	var selected: Array = []

	if available.is_empty():
		return selected

	# Build array of available items (we'll modify this)
	var pool = available.duplicate()

	for _i in range(min(count, pool.size())):
		if pool.is_empty():
			break

		# Calculate total weight once per selection
		var total_weight: float = 0.0
		for upgrade in pool:
			total_weight += upgrade.get_weight_for_rarity()

		if total_weight <= 0:
			break

		# Random selection
		var random_value = randf() * total_weight
		var current_weight: float = 0.0
		var selected_index: int = -1

		for j in range(pool.size()):
			current_weight += pool[j].get_weight_for_rarity()
			if random_value <= current_weight:
				selected_index = j
				break

		if selected_index >= 0:
			selected.append(pool[selected_index])
			pool.remove_at(selected_index)

	return selected

# ============================================
# APPLY UPGRADE
# ============================================
func apply_upgrade(player: Node2D, upgrade) -> bool:
	if not player or not player.stats:
		return false

	# Handle both UpgradeResource and legacy Dictionary
	if upgrade is UpgradeResource:
		return _apply_resource_upgrade(player, upgrade)
	elif upgrade is Dictionary:
		return _apply_legacy_upgrade(player, upgrade)

	return false

func _apply_resource_upgrade(player: Node2D, upgrade: UpgradeResource) -> bool:
	# Track non-instant upgrades
	if upgrade.upgrade_type != UpgradeResource.UpgradeType.INSTANT:
		picked_upgrades[upgrade.id] = picked_upgrades.get(upgrade.id, 0) + 1

	return upgrade.apply_to_player(player)

func _apply_legacy_upgrade(player: Node2D, upgrade: Dictionary) -> bool:
	# Track non-instant upgrades
	if upgrade.get("type", "stat") != "instant":
		var id = upgrade.get("id", "")
		picked_upgrades[id] = picked_upgrades.get(id, 0) + 1

	var apply_to = upgrade.get("stat_type", upgrade.get("apply_to", ""))
	var value = upgrade.get("value", 0.0)

	match apply_to:
		"max_health":
			player.stats.apply_upgrade("max_health", value)
			if upgrade.get("type") != "instant":
				player.heal(value)
			else:
				player.heal(player.stats.max_health)  # Full heal
		"melee_damage":
			player.stats.apply_upgrade("melee_damage", value)
		"magic_damage":
			player.stats.apply_upgrade("magic_damage", value)
		"all_damage":
			player.stats.apply_upgrade("melee_damage", value)
			player.stats.apply_upgrade("magic_damage", value)
		"move_speed":
			var is_percent = upgrade.get("is_percentage", false)
			if is_percent:
				var speed_increase = player.stats.move_speed * value
				player.stats.apply_upgrade("move_speed", speed_increase)
			else:
				player.stats.apply_upgrade("move_speed", value)
		"attack_speed":
			player.stats.apply_upgrade("attack_speed", value)
		"heal_full":
			player.heal(player.stats.max_health)
		"multi_shot":
			if player.current_staff:
				player.current_staff.multi_shot += int(value)
		"lifesteal":
			player.stats.lifesteal_amount += value
		"crit_chance":
			player.stats.crit_chance += value
		"crit_damage":
			player.stats.crit_damage += value
		_:
			return false

	return true

func reset_upgrades():
	picked_upgrades.clear()

# ============================================
# UTILITY - Get upgrade info for UI
# ============================================
func get_upgrade_display_data(upgrade) -> Dictionary:
	if upgrade is UpgradeResource:
		return {
			"id": upgrade.id,
			"name": upgrade.upgrade_name,
			"description": upgrade.description,
			"icon_color": upgrade.icon_color,
			"rarity_color": upgrade.get_rarity_color()
		}
	elif upgrade is Dictionary:
		return {
			"id": upgrade.get("id", ""),
			"name": upgrade.get("name", ""),
			"description": upgrade.get("description", ""),
			"icon_color": upgrade.get("icon_color", Color.WHITE),
			"rarity_color": Color.WHITE
		}
	return {}
