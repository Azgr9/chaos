# SCRIPT: RelicResource.gd
# LOCATION: res://Scripts/Resources/RelicResource.gd
# PURPOSE: Resource definition for relics (major passive items)

class_name RelicResource
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE, BOSS }

@export var id: String = ""
@export var relic_name: String = ""
@export var emoji: String = "💎"  # Emoji icon for HUD display
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON
@export_multiline var flavor_text: String = ""
@export_multiline var effect_description: String = ""
@export var unlock_cost: int = 0

# Stat bonuses
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

# Special effects (handled by code)
@export_group("Special")
@export var special_effect: String = ""

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
