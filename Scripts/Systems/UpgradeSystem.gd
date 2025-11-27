# SCRIPT: UpgradeSystem.gd
# ATTACH TO: Nothing - this is an autoload singleton
# LOCATION: res://scripts/systems/UpgradeSystem.gd

class_name UpgradeSystem
extends Node

# Upgrade definitions
var all_upgrades = [
	# Health upgrades
	{
		"id": "health_boost_small",
		"name": "Health Boost",
		"description": "+20 Max Health",
		"icon_color": Color.RED,
		"type": "stat",
		"apply_to": "max_health",
		"value": 20.0,
		"weight": 1.0
	},
	{
		"id": "health_boost_large",
		"name": "Vitality",
		"description": "+50 Max Health",
		"icon_color": Color.DARK_RED,
		"type": "stat",
		"apply_to": "max_health",
		"value": 50.0,
		"weight": 0.5
	},
	{
		"id": "heal_full",
		"name": "Full Heal",
		"description": "Restore all health",
		"icon_color": Color.PINK,
		"type": "instant",
		"apply_to": "heal_full",
		"value": 0,
		"weight": 0.8
	},

	# Damage upgrades
	{
		"id": "melee_damage_small",
		"name": "Sharp Blade",
		"description": "+25% Melee Damage",
		"icon_color": Color.ORANGE,
		"type": "stat",
		"apply_to": "melee_damage",
		"value": 0.25,
		"weight": 1.0
	},
	{
		"id": "magic_damage_small",
		"name": "Arcane Power",
		"description": "+25% Magic Damage",
		"icon_color": Color.CYAN,
		"type": "stat",
		"apply_to": "magic_damage",
		"value": 0.25,
		"weight": 1.0
	},
	{
		"id": "all_damage",
		"name": "Chaos Fury",
		"description": "+15% All Damage",
		"icon_color": Color.PURPLE,
		"type": "both",
		"apply_to": "all_damage",
		"value": 0.15,
		"weight": 0.6
	},

	# Speed upgrades
	{
		"id": "move_speed_small",
		"name": "Swift Boots",
		"description": "+20% Move Speed",
		"icon_color": Color.GREEN,
		"type": "stat",
		"apply_to": "move_speed",
		"value": 0.2,
		"weight": 1.0
	},
	{
		"id": "attack_speed",
		"name": "Berserker",
		"description": "+30% Attack Speed",
		"icon_color": Color.YELLOW,
		"type": "stat",
		"apply_to": "attack_speed",
		"value": 0.3,
		"weight": 0.8
	},

	# Weapon upgrades
	{
		"id": "extra_projectile",
		"name": "Multi-Shot",
		"description": "+1 Projectile per cast",
		"icon_color": Color.BLUE,
		"type": "special",
		"apply_to": "multi_shot",
		"value": 1,
		"weight": 0.4
	},

	# Special upgrades
	{
		"id": "vampirism",
		"name": "Vampirism",
		"description": "Heal 2 HP per kill",
		"icon_color": Color.DARK_RED,
		"type": "special",
		"apply_to": "lifesteal",
		"value": 2,
		"weight": 0.3
	}
]

# Track picked upgrades to avoid duplicates in same run
var picked_upgrades: Array = []
var upgrades_per_wave: int = 3

# Get random upgrades for selection
func get_random_upgrades(count: int = 3) -> Array:
	var available = []

	# Filter out already picked upgrades (optional - remove if you want repeats)
	for upgrade in all_upgrades:
		if not upgrade.id in picked_upgrades or upgrade.type == "instant":
			available.append(upgrade)

	# If not enough available, reset picked list
	if available.size() < count:
		picked_upgrades.clear()
		available = all_upgrades.duplicate()

	# Weighted random selection
	var selected = []
	for i in range(min(count, available.size())):
		var total_weight = 0.0
		for upgrade in available:
			total_weight += upgrade.weight

		var random_value = randf() * total_weight
		var current_weight = 0.0

		for upgrade in available:
			current_weight += upgrade.weight
			if random_value <= current_weight:
				selected.append(upgrade)
				available.erase(upgrade)
				break

	return selected

# Apply upgrade to player
func apply_upgrade(player: Node2D, upgrade: Dictionary):
	if not player or not player.stats:
		return

	# Track non-instant upgrades
	if upgrade.type != "instant":
		picked_upgrades.append(upgrade.id)

	match upgrade.apply_to:
		"max_health":
			player.stats.apply_upgrade("max_health", upgrade.value)
			player.heal(upgrade.value)  # Also heal when increasing max health
		"melee_damage":
			player.stats.apply_upgrade("melee_damage", upgrade.value)
		"magic_damage":
			player.stats.apply_upgrade("magic_damage", upgrade.value)
		"all_damage":
			player.stats.apply_upgrade("melee_damage", upgrade.value)
			player.stats.apply_upgrade("magic_damage", upgrade.value)
		"move_speed":
			var speed_increase = player.stats.move_speed * upgrade.value
			player.stats.apply_upgrade("move_speed", speed_increase)
		"attack_speed":
			player.stats.apply_upgrade("attack_speed", upgrade.value)
		"heal_full":
			player.heal(9999)  # Full heal
		"multi_shot":
			if player.current_staff:
				player.current_staff.multi_shot += int(upgrade.value)
		"lifesteal":
			player.stats.lifesteal_amount = upgrade.value

func reset_upgrades():
	picked_upgrades.clear()
