class_name PlayerStats
extends Resource

# Base stats
@export var max_health: float = 100.0
@export var move_speed: float = 450.0  # Pixels per second (scaled for 64x64 assets)
@export var melee_damage_multiplier: float = 1.0
@export var magic_damage_multiplier: float = 1.0
@export var attack_speed_multiplier: float = 1.0

# Attack Speed System
# Base attack speed cap (attacks per second) - global limit for this player
@export var base_attack_speed_cap: float = 4.0
# Current effective attack speed cap (modified by buffs/debuffs)
var effective_attack_speed_cap: float = 4.0
# Bonus attack speed from temporary effects (additive percentage: 0.2 = +20%)
var bonus_attack_speed: float = 0.0

# Special upgrades
@export var lifesteal_amount: float = 0.0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 1.5
@export var damage_reduction: float = 0.0

# Hazard resistance (0.0 = no resistance, 1.0 = immune)
@export var hazard_resistance: float = 0.0  # General hazard damage reduction
@export var fire_resistance: float = 0.0    # Fire grate resistance
@export var spike_resistance: float = 0.0   # Floor spikes and spike wall resistance
@export var pit_immunity: bool = false       # Immune to pit instant kill

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
			_recalculate_attack_speed_cap()

## Recalculate effective attack speed cap based on multipliers and bonuses
func _recalculate_attack_speed_cap():
	effective_attack_speed_cap = base_attack_speed_cap * attack_speed_multiplier * (1.0 + bonus_attack_speed)
	# Clamp to absolute maximum (10 attacks per second)
	effective_attack_speed_cap = minf(effective_attack_speed_cap, 10.0)

## Get the current effective attack speed multiplier
func get_attack_speed_multiplier() -> float:
	return attack_speed_multiplier * (1.0 + bonus_attack_speed)

## Add temporary bonus attack speed
func add_bonus_attack_speed(amount: float):
	bonus_attack_speed += amount
	_recalculate_attack_speed_cap()

## Remove temporary bonus attack speed
func remove_bonus_attack_speed(amount: float):
	bonus_attack_speed -= amount
	bonus_attack_speed = maxf(0.0, bonus_attack_speed)
	_recalculate_attack_speed_cap()

## Clear all temporary attack speed bonuses
func clear_bonus_attack_speed():
	bonus_attack_speed = 0.0
	_recalculate_attack_speed_cap()
