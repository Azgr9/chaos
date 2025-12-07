# SCRIPT: TrinketResource.gd
# LOCATION: res://Scripts/Resources/TrinketResource.gd
# PURPOSE: Resource definition for trinkets (minor passive items)

class_name TrinketResource
extends Resource

@export var id: String = ""
@export var trinket_name: String = ""
@export var icon: Texture2D
@export_multiline var flavor_text: String = ""
@export_multiline var effect_description: String = ""
@export var unlock_cost: int = 0
@export var shop_price_min: int = 30
@export var shop_price_max: int = 60

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

func get_random_price() -> int:
	return randi_range(shop_price_min, shop_price_max)
