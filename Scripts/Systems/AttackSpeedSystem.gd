# SCRIPT: AttackSpeedSystem.gd
# AUTOLOAD: AttackSpeedSystem
# LOCATION: res://Scripts/Systems/AttackSpeedSystem.gd
# PURPOSE: Centralized attack speed management with hard caps and controlled scaling

extends Node

# ============================================
# GLOBAL ATTACK SPEED CONSTANTS
# ============================================

# Base global attack speed limit: maximum attacks per second without any bonuses
const BASE_GLOBAL_ATTACKS_PER_SECOND: float = 4.0

# Absolute maximum attacks per second (hard cap that can never be exceeded)
const ABSOLUTE_MAX_ATTACKS_PER_SECOND: float = 10.0

# Minimum time between attacks (derived from absolute max)
const ABSOLUTE_MIN_ATTACK_INTERVAL: float = 1.0 / ABSOLUTE_MAX_ATTACKS_PER_SECOND  # 0.1 seconds

# Input timing bonus range (reward for well-timed inputs)
const INPUT_TIMING_BONUS_MIN: float = 0.0
const INPUT_TIMING_BONUS_MAX: float = 0.15  # Up to 15% bonus for perfect timing

# ============================================
# SIGNALS
# ============================================
signal attack_speed_changed(effective_attacks_per_second: float)

# ============================================
# STATE
# ============================================
# Cached player reference
var _player_reference: Node2D = null

# Global modifiers (from buffs, debuffs, temporary effects)
var _global_speed_modifiers: Dictionary = {}  # id -> modifier_value

# Last attack timestamps per weapon category
var _last_attack_time: Dictionary = {}  # weapon_id -> timestamp

# Input timing tracking for bonus calculation
var _last_input_time: float = 0.0
var _input_rhythm_score: float = 0.0

func _ready():
	# Get player reference after scene is ready
	await get_tree().process_frame
	_player_reference = get_tree().get_first_node_in_group("player")

# ============================================
# CORE API: Attack Speed Calculation
# ============================================

## Get the effective attack speed multiplier for a weapon
## This considers: global limit, weapon limit, buffs, and the lower of both
func get_effective_attack_speed(weapon: Node2D) -> float:
	var global_limit = _get_modified_global_limit()
	var weapon_limit = _get_weapon_speed_limit(weapon)

	# Return the LOWER of the two limits (more restrictive wins)
	return minf(global_limit, weapon_limit)

## Get the minimum time between attacks for a weapon (cooldown)
## Returns the actual cooldown in seconds that should be used
func get_effective_cooldown(weapon: Node2D, base_cooldown: float) -> float:
	var effective_speed = get_effective_attack_speed(weapon)

	# Convert attacks per second to minimum interval
	var min_interval_from_speed = 1.0 / effective_speed if effective_speed > 0 else base_cooldown

	# The cooldown cannot be lower than what the speed allows
	# But also respect the weapon's base cooldown modified by speed
	var speed_modified_cooldown = base_cooldown / _get_speed_multiplier()

	# Take the higher value (more restrictive)
	var final_cooldown = maxf(min_interval_from_speed, speed_modified_cooldown)

	# Never go below absolute minimum
	return maxf(final_cooldown, ABSOLUTE_MIN_ATTACK_INTERVAL)

## Check if an attack can be performed (respects timing limits)
func can_attack(weapon: Node2D) -> bool:
	var weapon_id = _get_weapon_id(weapon)
	var current_time = Time.get_ticks_msec() / 1000.0

	if not _last_attack_time.has(weapon_id):
		return true

	var last_attack = _last_attack_time[weapon_id]
	var min_interval = get_effective_cooldown(weapon, _get_weapon_base_cooldown(weapon))

	return (current_time - last_attack) >= min_interval

## Register that an attack was performed
func register_attack(weapon: Node2D):
	var weapon_id = _get_weapon_id(weapon)
	var current_time = Time.get_ticks_msec() / 1000.0

	# Calculate input timing bonus
	_update_input_rhythm(current_time)

	_last_attack_time[weapon_id] = current_time

## Register player input (for timing bonus calculation)
func register_input():
	var current_time = Time.get_ticks_msec() / 1000.0
	_update_input_rhythm(current_time)
	_last_input_time = current_time

# ============================================
# MODIFIERS API
# ============================================

## Add a temporary speed modifier (buff/debuff)
## modifier_value: percentage modifier (0.2 = +20% speed, -0.1 = -10% speed)
func add_modifier(modifier_id: String, modifier_value: float):
	_global_speed_modifiers[modifier_id] = modifier_value
	_emit_speed_change()

## Remove a speed modifier
func remove_modifier(modifier_id: String):
	_global_speed_modifiers.erase(modifier_id)
	_emit_speed_change()

## Clear all modifiers (useful for run reset)
func clear_all_modifiers():
	_global_speed_modifiers.clear()
	_last_attack_time.clear()
	_input_rhythm_score = 0.0
	_emit_speed_change()

## Get current input timing bonus (0.0 to INPUT_TIMING_BONUS_MAX)
func get_input_timing_bonus() -> float:
	return _input_rhythm_score * INPUT_TIMING_BONUS_MAX

# ============================================
# INTERNAL HELPERS
# ============================================

func _get_modified_global_limit() -> float:
	var base_limit = BASE_GLOBAL_ATTACKS_PER_SECOND

	# Apply player stats attack speed multiplier
	var player_multiplier = _get_speed_multiplier()

	# Apply all global modifiers
	var total_modifier = 1.0
	for modifier in _global_speed_modifiers.values():
		total_modifier += modifier

	# Apply input timing bonus
	total_modifier += get_input_timing_bonus()

	# Calculate final limit
	var final_limit = base_limit * player_multiplier * total_modifier

	# Clamp to absolute maximum
	return clampf(final_limit, 0.5, ABSOLUTE_MAX_ATTACKS_PER_SECOND)

func _get_weapon_speed_limit(weapon: Node2D) -> float:
	if not weapon:
		return BASE_GLOBAL_ATTACKS_PER_SECOND

	# Check if weapon has max_attacks_per_second property
	if "max_attacks_per_second" in weapon:
		var weapon_limit = weapon.max_attacks_per_second

		# Apply player speed multiplier to weapon limit too
		var player_multiplier = _get_speed_multiplier()
		var modified_limit = weapon_limit * player_multiplier

		# Apply global modifiers
		var total_modifier = 1.0
		for modifier in _global_speed_modifiers.values():
			total_modifier += modifier
		modified_limit *= total_modifier

		return clampf(modified_limit, 0.5, ABSOLUTE_MAX_ATTACKS_PER_SECOND)

	# Fallback: calculate from attack_cooldown if available
	if "attack_cooldown" in weapon:
		var base_cooldown = weapon.attack_cooldown
		if base_cooldown > 0:
			return 1.0 / base_cooldown

	return BASE_GLOBAL_ATTACKS_PER_SECOND

func _get_weapon_base_cooldown(weapon: Node2D) -> float:
	if weapon and "attack_cooldown" in weapon:
		return weapon.attack_cooldown
	return 0.25  # Default fallback

func _get_weapon_id(weapon: Node2D) -> String:
	if weapon:
		return str(weapon.get_instance_id())
	return "unknown"

func _get_speed_multiplier() -> float:
	# Try to get from player stats
	if _player_reference and _player_reference.stats:
		var stats = _player_reference.stats
		if "attack_speed_multiplier" in stats:
			return stats.attack_speed_multiplier

	# Try RunManager calculated stats
	if RunManager and RunManager.run_data.calculated_stats.has("cooldown_multiplier"):
		# cooldown_multiplier is inverted (lower = faster)
		# So we invert it for attack speed
		var cooldown_mult = RunManager.run_data.calculated_stats.cooldown_multiplier
		return 1.0 / cooldown_mult if cooldown_mult > 0 else 1.0

	return 1.0

func _update_input_rhythm(current_time: float):
	if _last_input_time <= 0:
		_input_rhythm_score = 0.0
		return

	var time_since_last = current_time - _last_input_time

	# Ideal rhythm is based on current effective attack speed
	# If player inputs match the rhythm, they get bonus
	var ideal_interval = 1.0 / BASE_GLOBAL_ATTACKS_PER_SECOND

	# Calculate how close to ideal timing this input was
	var timing_deviation = abs(time_since_last - ideal_interval) / ideal_interval

	# Perfect timing (deviation near 0) = high score
	# Poor timing (deviation > 0.5) = low score
	if timing_deviation < 0.3:
		# Good timing: increase rhythm score
		_input_rhythm_score = minf(_input_rhythm_score + 0.1, 1.0)
	elif timing_deviation > 0.7:
		# Poor timing: decrease rhythm score
		_input_rhythm_score = maxf(_input_rhythm_score - 0.15, 0.0)
	# else: maintain current score

func _emit_speed_change():
	var effective_speed = _get_modified_global_limit()
	attack_speed_changed.emit(effective_speed)

# ============================================
# UTILITY FUNCTIONS
# ============================================

## Get debug info about current attack speed state
func get_debug_info() -> Dictionary:
	return {
		"global_limit": _get_modified_global_limit(),
		"base_limit": BASE_GLOBAL_ATTACKS_PER_SECOND,
		"absolute_max": ABSOLUTE_MAX_ATTACKS_PER_SECOND,
		"speed_multiplier": _get_speed_multiplier(),
		"active_modifiers": _global_speed_modifiers.duplicate(),
		"input_timing_bonus": get_input_timing_bonus(),
		"rhythm_score": _input_rhythm_score
	}

## Calculate the attacks per second for a specific weapon
func get_weapon_attacks_per_second(weapon: Node2D) -> float:
	return get_effective_attack_speed(weapon)

## Get the actual cooldown that will be applied to a weapon
func get_weapon_effective_cooldown(weapon: Node2D) -> float:
	return get_effective_cooldown(weapon, _get_weapon_base_cooldown(weapon))
