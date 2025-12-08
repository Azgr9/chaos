# SCRIPT: UpgradeResource.gd
# LOCATION: res://Scripts/Resources/UpgradeResource.gd
# PURPOSE: Data-driven upgrade definitions - create .tres files for each upgrade

class_name UpgradeResource
extends Resource

# ============================================
# ENUMS
# ============================================
enum UpgradeType {
	STAT,       # Permanent stat increase
	INSTANT,    # One-time effect (heal, etc.)
	SPECIAL     # Custom effect (multi-shot, etc.)
}

enum StatType {
	MAX_HEALTH,
	MELEE_DAMAGE,
	MAGIC_DAMAGE,
	ALL_DAMAGE,
	MOVE_SPEED,
	ATTACK_SPEED,
	CRIT_CHANCE,
	CRIT_DAMAGE,
	LIFESTEAL,
	DAMAGE_REDUCTION,
	MULTI_SHOT
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY
}

# ============================================
# BASIC INFO
# ============================================
@export var id: String = ""
@export var upgrade_name: String = ""
@export_multiline var description: String = ""
@export var icon_color: Color = Color.WHITE
@export var rarity: Rarity = Rarity.COMMON

# ============================================
# UPGRADE BEHAVIOR
# ============================================
@export_group("Effect")
@export var upgrade_type: UpgradeType = UpgradeType.STAT
@export var stat_type: StatType = StatType.MAX_HEALTH
@export var value: float = 0.0
@export var is_percentage: bool = false  # True if value should be multiplied (e.g., +25% damage)

# ============================================
# BALANCE
# ============================================
@export_group("Balance")
@export var weight: float = 1.0  # Higher = more likely to appear
@export var can_repeat: bool = false  # Can this upgrade be picked multiple times?
@export var max_stacks: int = 1  # How many times can this be stacked (if can_repeat)

# ============================================
# REQUIREMENTS
# ============================================
@export_group("Requirements")
@export var min_wave: int = 1  # Minimum wave to appear
@export var requires_weapon_type: String = ""  # "melee", "magic", or "" for any

# ============================================
# METHODS
# ============================================
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color.GRAY
		Rarity.UNCOMMON:
			return Color.GREEN
		Rarity.RARE:
			return Color.BLUE
		Rarity.LEGENDARY:
			return Color.GOLD
	return Color.WHITE

func get_weight_for_rarity() -> float:
	# Base weight modified by rarity
	match rarity:
		Rarity.COMMON:
			return weight * 1.0
		Rarity.UNCOMMON:
			return weight * 0.6
		Rarity.RARE:
			return weight * 0.3
		Rarity.LEGENDARY:
			return weight * 0.1
	return weight

func apply_to_player(player: Node2D) -> bool:
	if not player or not player.stats:
		return false

	match upgrade_type:
		UpgradeType.STAT:
			return _apply_stat_upgrade(player)
		UpgradeType.INSTANT:
			return _apply_instant_upgrade(player)
		UpgradeType.SPECIAL:
			return _apply_special_upgrade(player)

	return false

func _apply_stat_upgrade(player: Node2D) -> bool:
	var stats = player.stats

	match stat_type:
		StatType.MAX_HEALTH:
			stats.apply_upgrade("max_health", value)
			player.heal(value)  # Also heal when increasing max health
		StatType.MELEE_DAMAGE:
			stats.apply_upgrade("melee_damage", value)
		StatType.MAGIC_DAMAGE:
			stats.apply_upgrade("magic_damage", value)
		StatType.ALL_DAMAGE:
			stats.apply_upgrade("melee_damage", value)
			stats.apply_upgrade("magic_damage", value)
		StatType.MOVE_SPEED:
			if is_percentage:
				var speed_increase = stats.move_speed * value
				stats.apply_upgrade("move_speed", speed_increase)
			else:
				stats.apply_upgrade("move_speed", value)
		StatType.ATTACK_SPEED:
			stats.apply_upgrade("attack_speed", value)
		StatType.CRIT_CHANCE:
			stats.crit_chance += value
		StatType.CRIT_DAMAGE:
			stats.crit_damage += value
		StatType.LIFESTEAL:
			stats.lifesteal_amount += value
		StatType.DAMAGE_REDUCTION:
			stats.damage_reduction += value
		_:
			return false

	return true

func _apply_instant_upgrade(player: Node2D) -> bool:
	match stat_type:
		StatType.MAX_HEALTH:
			# Full heal
			player.heal(player.stats.max_health)
			return true
		_:
			return false

func _apply_special_upgrade(player: Node2D) -> bool:
	match stat_type:
		StatType.MULTI_SHOT:
			if player.current_staff:
				player.current_staff.multi_shot += int(value)
				return true
		_:
			return false

	return false
