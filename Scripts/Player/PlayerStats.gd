class_name PlayerStats
extends Resource

# Base stats
@export var max_health: float = 100.0
@export var move_speed: float = 450.0  # Pixels per second (scaled for 64x64 assets)
@export var melee_damage_multiplier: float = 1.0
@export var magic_damage_multiplier: float = 1.0
@export var attack_speed_multiplier: float = 1.0

# Special upgrades
@export var lifesteal_amount: float = 0.0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 1.5

# Current values
var current_health: float

func _init():
	current_health = max_health

func reset_health():
	current_health = max_health

func take_damage(amount: float) -> bool:
	current_health -= amount
	current_health = max(0, current_health)
	return current_health <= 0  # Returns true if dead

func heal(amount: float):
	current_health = min(current_health + amount, max_health)

func get_health_percentage() -> float:
	return current_health / max_health if max_health > 0 else 0.0

func apply_upgrade(upgrade_type: String, value: float):
	match upgrade_type:
		"max_health":
			var health_ratio = get_health_percentage()
			max_health += value
			current_health = max_health * health_ratio
		"move_speed":
			move_speed += value
		"melee_damage":
			melee_damage_multiplier += value
		"magic_damage":
			magic_damage_multiplier += value
		"attack_speed":
			attack_speed_multiplier += value
