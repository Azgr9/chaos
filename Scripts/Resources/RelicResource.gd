# SCRIPT: RelicResource.gd
# LOCATION: res://Scripts/Resources/RelicResource.gd
# PURPOSE: Resource definition for relics (major passive items)

class_name RelicResource
extends Resource

# ============================================
# ENUMS
# ============================================
enum Rarity { COMMON, UNCOMMON, RARE, BOSS }

# ============================================
# BASIC INFO
# ============================================
@export var id: String = ""
@export var relic_name: String = ""
@export var emoji: String = "💎"  # Emoji icon for HUD display
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON
@export_multiline var flavor_text: String = ""
@export_multiline var effect_description: String = ""
@export var unlock_cost: int = 0

# ============================================
# STAT BONUSES
# ============================================
@export_group("Stats")
@export var max_health_bonus: int = 0
@export var damage_percent: float = 0.0
@export var speed_percent: float = 0.0
@export var cooldown_percent: float = 0.0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 0.0
@export var lifesteal: float = 0.0
@export var damage_reduction: float = 0.0
@export var gold_multiplier: float = 0.0
@export var durability_bonus: float = 0.0

# ============================================
# SPECIAL EFFECTS
# ============================================
@export_group("Special")
@export var special_effect: String = ""  # e.g., "phoenix_revive", "thorns", etc.
@export var special_value: float = 0.0   # Value for special effect if needed

# ============================================
# UTILITY METHODS
# ============================================
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color.GRAY
		Rarity.UNCOMMON:
			return Color.GREEN
		Rarity.RARE:
			return Color.BLUE
		Rarity.BOSS:
			return Color.PURPLE
	return Color.WHITE

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.BOSS:
			return "Boss"
	return "Unknown"

# ============================================
# APPLY METHOD - Self-contained stat application
# ============================================
func apply_to_stats(stats: Dictionary) -> Dictionary:
	"""
	Apply this relic's bonuses to a stats dictionary.
	Returns the modified stats.

	Usage:
		var stats = RunManager.run_data.calculated_stats
		stats = relic.apply_to_stats(stats)
	"""
	var result = stats.duplicate()

	if max_health_bonus != 0:
		result["max_health"] = result.get("max_health", 100.0) + max_health_bonus

	if damage_percent != 0:
		result["damage_multiplier"] = result.get("damage_multiplier", 1.0) + damage_percent

	if speed_percent != 0:
		result["speed_multiplier"] = result.get("speed_multiplier", 1.0) + speed_percent

	if cooldown_percent != 0:
		var new_cooldown = result.get("cooldown_multiplier", 1.0) + cooldown_percent
		result["cooldown_multiplier"] = max(0.3, new_cooldown)  # Minimum 30% cooldown

	if crit_chance != 0:
		result["crit_chance"] = result.get("crit_chance", 0.0) + crit_chance

	if crit_damage != 0:
		result["crit_damage"] = result.get("crit_damage", 1.5) + crit_damage

	if lifesteal != 0:
		result["lifesteal"] = result.get("lifesteal", 0.0) + lifesteal

	if damage_reduction != 0:
		result["damage_reduction"] = result.get("damage_reduction", 0.0) + damage_reduction

	if gold_multiplier != 0:
		result["gold_multiplier"] = result.get("gold_multiplier", 1.0) + gold_multiplier

	if durability_bonus != 0:
		result["durability_multiplier"] = result.get("durability_multiplier", 1.0) + durability_bonus

	return result

func has_special_effect(effect_name: String) -> bool:
	"""Check if this relic has a specific special effect."""
	return special_effect == effect_name

func get_stat_summary() -> String:
	"""Get a formatted string of all stat bonuses."""
	var parts: Array[String] = []

	if max_health_bonus != 0:
		parts.append("+%d HP" % max_health_bonus)
	if damage_percent != 0:
		parts.append("+%d%% Damage" % int(damage_percent * 100))
	if speed_percent != 0:
		parts.append("+%d%% Speed" % int(speed_percent * 100))
	if cooldown_percent != 0:
		parts.append("%d%% Cooldown" % int(cooldown_percent * 100))
	if crit_chance != 0:
		parts.append("+%d%% Crit" % int(crit_chance * 100))
	if crit_damage != 0:
		parts.append("+%d%% Crit DMG" % int(crit_damage * 100))
	if lifesteal != 0:
		parts.append("+%.1f Lifesteal" % lifesteal)
	if damage_reduction != 0:
		parts.append("+%d%% DR" % int(damage_reduction * 100))
	if gold_multiplier != 0:
		parts.append("+%d%% Gold" % int(gold_multiplier * 100))

	if special_effect != "":
		parts.append("[%s]" % special_effect)

	return ", ".join(parts) if parts.size() > 0 else "No stat bonuses"
